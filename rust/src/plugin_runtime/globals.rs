//! What a plugin script sees: the `Response` helper, `load()`, and the call of
//! the global `execute(input)` with the check of what it returned.
//!
//! Scripts are classic global scripts (sloppy mode, no modules): the entry
//! file and every file it `load()`s share one global scope.

use std::cell::RefCell;
use std::collections::{HashMap, HashSet};
use std::rc::Rc;
use std::sync::Arc;

use rquickjs::context::EvalOptions;
use rquickjs::{
    CatchResultExt, CaughtError, Coerced, Ctx, Exception, FromJs, Function, Object, Value,
};

use super::limits::{MAX_ERROR_MESSAGE_CHARS, MAX_ERROR_STACK_BYTES, MAX_OUTPUT_BYTES};
use crate::api::plugin_runtime::PluginErrorKind;

/// The package's `src/` files by name.
pub type Sources = Arc<HashMap<String, String>>;

/// Defines the global `Response` (frozen, not writable) and returns the brand
/// check (`isResponse`: true only for objects `Response.success` /
/// `Response.error` made) and `lengthOf` (UTF-16 length of a string).
/// The helpers capture the built-ins they use when the prelude runs, and call
/// them through bound functions (`call.bind(fn)`), so a script that replaces
/// `Object.freeze`, `WeakSet.prototype`, `Function.prototype.call`/`bind` or
/// `Reflect.apply` afterwards cannot forge or break a response.
const PRELUDE: &str = r#"
(function () {
  'use strict';
  var freeze = Object.freeze;
  var made = new WeakSet();
  var call = Function.prototype.call;
  var add = call.bind(WeakSet.prototype.add);
  var has = call.bind(WeakSet.prototype.has);
  var isFinite_ = isFinite, floor = Math.floor, min = Math.min, Str = String;
  function brand(o) { freeze(o); add(made, o); return o; }
  var Response = freeze({
    success: function success(data) { return brand({ ok: true, data: data }); },
    error: function error(message, options) {
      var kind = 'server', retry = null;
      if (options !== null && typeof options === 'object') {
        var k = options.kind;
        if (k === 'rateLimited' || k === 'invalidResponse' || k === 'server') kind = k;
        var r = options.retryAfterSec;
        if (typeof r === 'number' && isFinite_(r) && r >= 0) retry = min(floor(r), 4294967295);
      }
      return brand({ ok: false, message: Str(message), kind: kind, retryAfterSec: retry });
    }
  });
  Object.defineProperty(globalThis, 'Response',
    { value: Response, writable: false, configurable: false, enumerable: false });
  return {
    isResponse: function isResponse(v) { return has(made, v); },
    lengthOf: function lengthOf(s) { return s.length; }
  };
})()
"#;

/// Helper functions the prelude hands to the host.
pub struct Helpers<'js> {
    is_response: Function<'js>,
    length_of: Function<'js>,
}

/// An exception, a syntax error or an engine error, as owned text.
#[derive(Debug, Clone, Default)]
pub struct JsFailure {
    /// The exception's `name` (`RangeError`, ...); empty for non-objects.
    pub name: String,
    pub message: String,
    /// Empty when the engine gave none.
    pub stack: String,
}

/// Why a run did not end in a `Response`.
#[derive(Debug)]
pub enum RunFailure {
    /// The engine threw: an exception, a limit, an interrupt.
    Js(JsFailure),
    /// The script broke the contract (no `execute`, bad `load()` name found
    /// by the host, ...); text made by the runtime.
    Contract(String),
    /// `execute` did not return a `Response`.
    InvalidResponse(String),
    /// The data is larger than the output cap.
    OutputTooLarge,
}

/// A `Response` the script returned.
#[derive(Debug)]
pub enum Finished {
    Success {
        output_json: String,
    },
    ScriptError {
        message: String,
        kind: PluginErrorKind,
        retry_after_sec: Option<u32>,
    },
}

/// Turns an engine error into owned text. `ctx.catch()` takes the pending
/// exception, so call this once per error.
pub fn describe_error<'js>(ctx: &Ctx<'js>, err: rquickjs::Error) -> JsFailure {
    let caught: Result<(), CaughtError<'js>> = Err::<(), _>(err).catch(ctx);
    let mut failure = match caught {
        Ok(()) => JsFailure::default(),
        Err(CaughtError::Exception(e)) => JsFailure {
            name: e
                .get::<_, Option<String>>("name")
                .ok()
                .flatten()
                .unwrap_or_default(),
            message: e.message().unwrap_or_default(),
            stack: e.stack().unwrap_or_default(),
        },
        Err(CaughtError::Value(v)) => JsFailure {
            message: Coerced::<String>::from_js(ctx, v)
                .map(|c| c.0)
                .unwrap_or_else(|_| "non-string value thrown".to_owned()),
            ..JsFailure::default()
        },
        Err(CaughtError::Error(rquickjs::Error::Allocation)) => JsFailure {
            message: "out of memory".to_owned(),
            ..JsFailure::default()
        },
        Err(CaughtError::Error(e)) => JsFailure {
            message: e.to_string(),
            ..JsFailure::default()
        },
    };
    failure.message = truncate_chars(failure.message, MAX_ERROR_MESSAGE_CHARS);
    failure.stack = truncate_bytes(failure.stack, MAX_ERROR_STACK_BYTES);
    failure
}

/// Cuts `s` to at most `max` characters.
fn truncate_chars(s: String, max: usize) -> String {
    match s.char_indices().nth(max) {
        Some((i, _)) => s[..i].to_owned(),
        None => s,
    }
}

/// Cuts `s` to at most `max` bytes, on a character boundary.
fn truncate_bytes(mut s: String, max: usize) -> String {
    if s.len() > max {
        let mut cut = max;
        while !s.is_char_boundary(cut) {
            cut -= 1;
        }
        s.truncate(cut);
    }
    s
}

/// Runs `code` as a classic global script named `filename`.
pub fn eval_classic<'js>(
    ctx: &Ctx<'js>,
    code: &str,
    filename: &str,
) -> rquickjs::Result<Value<'js>> {
    let mut options = EvalOptions::default();
    options.strict = false;
    options.filename = Some(filename.to_owned());
    ctx.eval_with_options::<Value, _>(code, options)
}

/// True for `name.js` made of letters, digits, `_`, `.` and `-` only (no folders).
pub fn is_loadable_name(name: &str) -> bool {
    name.len() > ".js".len()
        && name.ends_with(".js")
        && name
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || matches!(b, b'_' | b'.' | b'-'))
}

/// Installs `Response` and `load()`; returns the prelude helpers.
/// `entry` counts as already loaded.
pub fn install<'js>(
    ctx: &Ctx<'js>,
    sources: Sources,
    entry: &str,
    #[cfg_attr(not(test), allow(unused_variables))] collector: &super::collector::Collector,
) -> rquickjs::Result<Helpers<'js>> {
    let helpers: Object = eval_classic(ctx, PRELUDE, "<runtime>")?
        .into_object()
        .ok_or_else(|| Exception::throw_message(ctx, "prelude did not return an object"))?;
    let helpers = Helpers {
        is_response: helpers.get("isResponse")?,
        length_of: helpers.get("lengthOf")?,
    };

    let loaded: Rc<RefCell<HashSet<String>>> =
        Rc::new(RefCell::new(HashSet::from([entry.to_owned()])));
    let load = Function::new(
        ctx.clone(),
        move |ctx: Ctx<'_>, name: String| -> rquickjs::Result<()> {
            if !is_loadable_name(&name) {
                return Err(Exception::throw_message(
                    &ctx,
                    "load: the name must be a file name like util.js (letters, digits, _ . - only)",
                ));
            }
            if name == "crypto.js" {
                return Err(Exception::throw_message(
                    &ctx,
                    "load: crypto.js is reserved and not available yet",
                ));
            }
            let Some(code) = sources.get(&name) else {
                return Err(Exception::throw_message(
                    &ctx,
                    &format!("load: no file named {name} in src/"),
                ));
            };
            if !loaded.borrow_mut().insert(name.clone()) {
                return Ok(());
            }
            eval_classic(&ctx, code, &name).map(|_| ())
        },
    )?;
    ctx.globals().set("load", load)?;

    #[cfg(test)]
    install_test_hooks(ctx, collector)?;
    Ok(helpers)
}

/// Host functions only the unit tests have: they let a test write a console
/// line or panic from inside the script.
#[cfg(test)]
fn install_test_hooks<'js>(
    ctx: &Ctx<'js>,
    collector: &super::collector::Collector,
) -> rquickjs::Result<()> {
    let sink = collector.clone();
    let log = Function::new(ctx.clone(), move |line: String| sink.push_log(line))?;
    ctx.globals().set("__testLog", log)?;
    let panic_fn = Function::new(ctx.clone(), || -> () {
        panic!("test host function panicked")
    })?;
    ctx.globals().set("__testPanic", panic_fn)?;
    Ok(())
}

/// Calls the global `execute(input)` and checks what it returned.
pub fn call_execute<'js>(
    ctx: &Ctx<'js>,
    input: Value<'js>,
    helpers: &Helpers<'js>,
) -> Result<Finished, RunFailure> {
    let execute: Value = ctx
        .globals()
        .get("execute")
        .map_err(|e| RunFailure::Js(describe_error(ctx, e)))?;
    let Some(execute) = execute.as_function() else {
        return Err(RunFailure::Contract(
            "the entry script must define a global function execute(input)".to_owned(),
        ));
    };
    let returned: Value = execute
        .call((input,))
        .map_err(|e| RunFailure::Js(describe_error(ctx, e)))?;
    let branded: bool = helpers
        .is_response
        .call((returned.clone(),))
        .map_err(|e| RunFailure::Js(describe_error(ctx, e)))?;
    if !branded {
        return Err(RunFailure::InvalidResponse(
            "execute must return Response.success or Response.error".to_owned(),
        ));
    }
    let response: Object = returned
        .into_object()
        .ok_or_else(|| RunFailure::Contract("response is not an object".to_owned()))?;
    read_response(ctx, &response, helpers)
}

fn read_response<'js>(
    ctx: &Ctx<'js>,
    response: &Object<'js>,
    helpers: &Helpers<'js>,
) -> Result<Finished, RunFailure> {
    let js = |e| RunFailure::Js(describe_error(ctx, e));
    let ok: bool = response.get("ok").map_err(js)?;
    if ok {
        let data: Value = response.get("data").map_err(js)?;
        let json = match ctx.json_stringify(data).map_err(js)? {
            Some(s) => {
                // UTF-8 is never shorter than the UTF-16 length QuickJS keeps,
                // so a longer string is refused before it is copied.
                let units: usize = helpers.length_of.call((s.clone(),)).map_err(js)?;
                if units > MAX_OUTPUT_BYTES {
                    return Err(RunFailure::OutputTooLarge);
                }
                s.to_string().map_err(js)?
            }
            None => "null".to_owned(), // `undefined` data
        };
        if json.len() > MAX_OUTPUT_BYTES {
            return Err(RunFailure::OutputTooLarge);
        }
        return Ok(Finished::Success { output_json: json });
    }
    let message: String = response.get("message").map_err(js)?;
    let kind: String = response.get("kind").map_err(js)?;
    let retry: Option<f64> = response.get("retryAfterSec").map_err(js)?;
    Ok(Finished::ScriptError {
        message: message.chars().take(MAX_ERROR_MESSAGE_CHARS).collect(),
        kind: match kind.as_str() {
            "rateLimited" => PluginErrorKind::RateLimited,
            "invalidResponse" => PluginErrorKind::InvalidResponse,
            _ => PluginErrorKind::Server,
        },
        retry_after_sec: retry.map(|r| r.min(f64::from(u32::MAX)) as u32),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn loadable_names() {
        for ok in ["a.js", "util-2.js", "A_b.c.js", "..js"] {
            assert!(is_loadable_name(ok), "{ok}");
        }
        for bad in [
            "", ".js", "a", "a.json", "../x.js", "a/b.js", "a b.js", "a\\b.js", "é.js", "a.js\0",
        ] {
            assert!(!is_loadable_name(bad), "{bad:?}");
        }
    }
}
