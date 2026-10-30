//! Compile-only check of a plugin script: parses it as a classic global
//! script and never runs it, so a top-level `throw` or an endless loop is
//! not executed.

use std::ffi::CString;
use std::thread;

use rquickjs::{qjs, CatchResultExt, CaughtError, Context, Ctx, Runtime};

use super::limits::{MEMORY_LIMIT_BYTES, SCRIPT_STACK_BYTES, THREAD_STACK_BYTES};
use super::memory::LimitedAllocator;
use crate::api::plugin_runtime::PluginScriptProblem;

/// `None` when `code` parses, else the first problem. Runs on a thread of its
/// own with the worker stack size, because the caller is a bridge worker with
/// a small stack and the parser recurses.
pub fn check_script(name: &str, code: &str) -> Option<PluginScriptProblem> {
    let (name, code) = (name.to_owned(), code.to_owned());
    let spawned = thread::Builder::new()
        .name("plugin-js-check".to_owned())
        .stack_size(THREAD_STACK_BYTES)
        .spawn(move || check_on_this_thread(&name, &code));
    match spawned.map(|handle| handle.join()) {
        Ok(Ok(problem)) => problem,
        _ => Some(PluginScriptProblem {
            message: "the syntax check could not run".to_owned(),
            line: 0,
        }),
    }
}

fn check_on_this_thread(name: &str, code: &str) -> Option<PluginScriptProblem> {
    let internal = |what: &str| {
        Some(PluginScriptProblem {
            message: format!("the syntax check could not run: {what}"),
            line: 0,
        })
    };
    let (allocator, _memory_hit) = LimitedAllocator::new(MEMORY_LIMIT_BYTES);
    let runtime = match Runtime::new_with_alloc(allocator) {
        Ok(rt) => rt,
        Err(e) => return internal(&e.to_string()),
    };
    runtime.set_max_stack_size(SCRIPT_STACK_BYTES);
    let context = match Context::full(&runtime) {
        Ok(c) => c,
        Err(e) => return internal(&e.to_string()),
    };
    let problem = context.with(|ctx| compile_only(&ctx, name, code));
    drop(context);
    drop(runtime);
    problem
}

fn compile_only(ctx: &Ctx<'_>, name: &str, code: &str) -> Option<PluginScriptProblem> {
    let Ok(source) = CString::new(code) else {
        return Some(PluginScriptProblem {
            message: "the script contains a NUL character".to_owned(),
            line: 0,
        });
    };
    let file = CString::new(name).unwrap_or_else(|_| c"plugin.js".to_owned());
    let flags = (qjs::JS_EVAL_TYPE_GLOBAL | qjs::JS_EVAL_FLAG_COMPILE_ONLY) as i32;
    // SAFETY: `ctx` is a live context of this thread; `source` and `file` are
    // NUL-terminated and outlive the call (the length is passed explicitly);
    // the returned value is freed below unless it is the exception marker.
    let value = unsafe {
        qjs::JS_Eval(
            ctx.as_raw().as_ptr(),
            source.as_ptr(),
            code.len() as _,
            file.as_ptr(),
            flags,
        )
    };
    // SAFETY: `value` was just returned by `JS_Eval` for this context.
    if !unsafe { qjs::JS_IsException(value) } {
        unsafe { qjs::JS_FreeValue(ctx.as_raw().as_ptr(), value) };
        return None;
    }
    let caught: Result<(), CaughtError<'_>> = Err::<(), _>(rquickjs::Error::Exception).catch(ctx);
    let (message, stack) = match caught {
        Err(CaughtError::Exception(e)) => (
            e.message().unwrap_or_default(),
            e.stack().unwrap_or_default(),
        ),
        Err(other) => (other.to_string(), String::new()),
        Ok(()) => (String::new(), String::new()),
    };
    let line = line_in_stack(&stack, name);
    Some(PluginScriptProblem { message, line })
}

/// The first `name:LINE` in an engine stack text; 0 when there is none.
fn line_in_stack(stack: &str, name: &str) -> u32 {
    stack
        .split(&format!("{name}:") as &str)
        .nth(1)
        .map(|rest| {
            rest.chars()
                .take_while(char::is_ascii_digit)
                .collect::<String>()
        })
        .and_then(|digits| digits.parse().ok())
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_script_passes() {
        assert_eq!(
            check_script("a.js", "function execute(i) { return 1; }"),
            None
        );
    }

    #[test]
    fn syntax_error_reports_the_line() {
        let p = check_script("search.js", "var a = 1;\nvar b = 2;\nvar c = ;\n").expect("problem");
        assert_eq!(p.line, 3, "{p:?}");
        assert!(!p.message.is_empty());
    }

    #[test]
    fn top_level_throw_is_not_run() {
        assert_eq!(
            check_script("a.js", "throw new Error('x'); while (true) {}"),
            None
        );
    }

    #[test]
    fn sloppy_code_compiles() {
        assert_eq!(
            check_script("a.js", "with (Math) { var x = max(1, 2); } var o = 010;"),
            None
        );
    }

    #[test]
    fn nul_is_a_problem_not_a_panic() {
        assert!(check_script("a.js", "var a;\0").is_some());
    }

    #[test]
    fn line_parsing() {
        assert_eq!(line_in_stack("    at a.js:12:5\n", "a.js"), 12);
        assert_eq!(line_in_stack("no position", "a.js"), 0);
    }
}
