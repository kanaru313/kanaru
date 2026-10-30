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
