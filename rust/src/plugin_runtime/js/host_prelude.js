// Evaluates to a function that receives the Rust natives and defines the host
// API globals. Runs before any plugin code, in strict mode, and keeps its own
// references to the built-ins it uses.
(function (n) {
  'use strict';
  var freeze = Object.freeze, defineProperty = Object.defineProperty;
  var Str = String, Num = Number, Err = Error;
  var stringify = JSON.stringify, parse = JSON.parse;
  var call = Function.prototype.call;
  var join = call.bind(Array.prototype.join);
  var lower = call.bind(String.prototype.toLowerCase);
  var slice = call.bind(String.prototype.slice);
  var wellFormed = call.bind(String.prototype.toWellFormed);
  var charCodeAt = call.bind(String.prototype.charCodeAt);
  var hasOwn = call.bind(Object.prototype.hasOwnProperty);

  // Strings that reach Rust must be valid Unicode; a lone surrogate would fail
  // the conversion. Data is not repaired here: throw instead. (Console lines
  // are the one place where a lone surrogate is repaired, see `logger`.)
  function strict(v) {
    var s = Str(v);
    if (wellFormed(s) !== s) {
      throw new TypeError('strings passed to the host must be well-formed Unicode (no lone surrogates)');
    }
    return s;
  }

  function orNull(v) { return v === undefined ? null : v; }

  function makeError(name, message) {
    var e = new Err(message);
    defineProperty(e, 'name', { value: name, writable: true, configurable: true, enumerable: false });
    return e;
  }

  // Ordinary global properties: a script may still declare its own `sleep` or `fetch`.
  function define(name, value) {
    defineProperty(globalThis, name,
      { value: value, writable: true, configurable: true, enumerable: false });
  }

  // `flat` is name, value, name, value, ...
  function makeHeaders(flat) {
    var o = {};
    for (var i = 0; i + 1 < flat.length; i += 2) {
      defineProperty(o, flat[i],
        { value: flat[i + 1], writable: true, configurable: true, enumerable: true });
    }
    return o;
  }

  // The body stays in Rust until the first read; the result is cached here.
  function makeResponse(r) {
    var id = r.id, text_, b64_;
    var headers = makeHeaders(r.headers);
    function readText(charset) {
      if (text_ === undefined) {
        if (b64_ !== undefined) throw makeError('Error', 'the body was already read as base64');
        text_ = n.bodyText(id, charset === undefined || charset === null ? '' : strict(charset));
      }
      return text_;
    }
    return freeze({
      status: r.status,
      ok: r.status >= 200 && r.status <= 299,
      url: r.url,
      headers: freeze(headers),
      header: function header(name) {
        var key = lower(Str(name));
        return hasOwn(headers, key) ? headers[key] : null;
      },
      text: function text(charset) { return readText(charset); },
      json: function json() { return parse(readText()); },
      base64: function base64() {
        if (b64_ === undefined) {
          if (text_ !== undefined) throw makeError('Error', 'the body was already read as text');
          b64_ = n.bodyBase64(id);
        }
        return b64_;
      }
    });
  }

  define('fetch', function fetch(url, options) {
    var r = n.fetch(strict(url), options);
    if (r.error !== undefined) {
      var e = makeError(r.error, r.message);
      if (r.retryAfterSec !== undefined) e.retryAfterSec = r.retryAfterSec;
      throw e;
    }
    return makeResponse(r);
  });

  define('sleep', function sleep(ms) { n.sleep(Num(ms)); });

  define('localConfig', freeze({
    getItem: function getItem(key) { return orNull(n.configGet(strict(key))); }
  }));

  define('localStorage', freeze({
    getItem: function getItem(key) { return orNull(n.storageGet(strict(key))); },
    setItem: function setItem(key, value) {
      if (!n.storageSet(strict(key), strict(value))) {
        throw makeError('QuotaExceededError', 'localStorage is full (64 KiB for keys and values)');
      }
    },
    removeItem: function removeItem(key) { n.storageRemove(strict(key)); },
    clear: function clear() { n.storageClear(); }
  }));

  // Html: `Element` and `Elements` keep their Rust handles in private fields, so
  // a script can neither read nor make up a handle. The constructors need a token
  // only this closure has, so `new el.constructor(...)` cannot forge one either.
  var htmlToken = {};
  function wrapElement(h) { return new Element(htmlToken, h); }
  function wrapElements(handles) { return new Elements(htmlToken, handles); }
  function checkFn(fn) {
    if (typeof fn !== 'function') throw new TypeError('the callback must be a function');
    return fn;
  }

  class Element {
    #h;
    constructor(token, h) {
      if (token !== htmlToken) throw new TypeError('Element cannot be constructed by a script');
      this.#h = h;
    }
    select(css) { return wrapElements(n.htmlSelect(this.#h, strict(css), false)); }
    selectFirst(css) {
      var r = n.htmlSelect(this.#h, strict(css), true);
      return r.length === 0 ? null : wrapElement(r[0]);
    }
    text() { return n.htmlText(this.#h); }
    html() { return n.htmlHtml(this.#h, false); }
    outerHtml() { return n.htmlHtml(this.#h, true); }
    attr(name) { return n.htmlAttr(this.#h, strict(name)); }
    tagName() { return n.htmlTag(this.#h); }
  }

  class Elements {
    #hs;
    constructor(token, handles) {
      if (token !== htmlToken) throw new TypeError('Elements cannot be constructed by a script');
      this.#hs = handles;
    }
    size() { return this.#hs.length; }
    get(i) {
      var h = this.#hs[Num(i)];
      return h === undefined ? null : wrapElement(h);
    }
    first() { return this.get(0); }
    last() { return this.get(this.#hs.length - 1); }
    text() {
      var parts = [];
      for (var i = 0; i < this.#hs.length; i++) parts[i] = n.htmlText(this.#hs[i]);
      return join(parts, '\n');
    }
    attr(name) { return this.#hs.length === 0 ? '' : n.htmlAttr(this.#hs[0], strict(name)); }
    map(fn) {
      checkFn(fn);
      var out = [];
      for (var i = 0; i < this.#hs.length; i++) out[i] = fn(wrapElement(this.#hs[i]), i);
      return out;
    }
    forEach(fn) {
      checkFn(fn);
      for (var i = 0; i < this.#hs.length; i++) fn(wrapElement(this.#hs[i]), i);
    }
    toArray() {
      var out = [];
      for (var i = 0; i < this.#hs.length; i++) out[i] = wrapElement(this.#hs[i]);
      return out;
    }
  }

  define('Html', freeze({
    parse: function parse(text) { return wrapElement(n.htmlParse(strict(text))); }
  }));

  function format(a) {
    if (typeof a === 'string') return a;
    if (a !== null && typeof a === 'object' && !(a instanceof Err)) {
      try {
        var s = stringify(a);
        if (typeof s === 'string') return s;
      } catch (e) { /* cyclic or throwing toJSON: fall back to String() */ }
    }
    try {
      return Str(a);
    } catch (e) {
      return '[unprintable value]';
    }
  }
  function logger() {
    var parts = [];
    for (var i = 0; i < arguments.length; i++) parts[i] = format(arguments[i]);
    var line = join(parts, ' ');
    if (line.length > 4000) {
      // Rust cuts at 500 characters; do not cut a surrogate pair in half.
      var end = 4000, last = charCodeAt(line, end - 1);
      if (last >= 0xD800 && last <= 0xDBFF) end--;
      line = slice(line, 0, end);
    }
    n.log(wellFormed(line));
  }
  define('console', {
    log: logger, info: logger, warn: logger, error: logger, debug: logger
  });
  define('Log', { log: logger });
})
