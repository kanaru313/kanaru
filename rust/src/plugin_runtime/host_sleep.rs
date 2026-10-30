//! `sleep(ms)`: blocks the JS thread, the only way a script waits.

use std::rc::Rc;
use std::sync::atomic::Ordering;
use std::thread;
use std::time::{Duration, Instant};

use rquickjs::{Ctx, Function, Object};

use super::host::{HostEnv, STOP_CANCELLED, STOP_TIMEOUT};
use super::limits::CANCEL_POLL;

/// Longest single request honoured before clamping, so `Duration` cannot overflow.
const MAX_REQUEST_MS: f64 = 1.0e9;

fn sleep<'js>(ctx: &Ctx<'js>, env: &HostEnv, ms: f64) -> rquickjs::Result<()> {
    env.check_alive(ctx)?;
    let ms = if ms.is_finite() && ms > 0.0 {
        ms.min(MAX_REQUEST_MS)
    } else {
        0.0
    };
    let wanted = Duration::from_secs_f64(ms / 1000.0);
    let remaining = env.remaining();
    // The sleep counts toward the call's wall time: never longer than what is left.
    let end = Instant::now() + wanted.min(remaining);
    loop {
        if env.cancel.load(Ordering::SeqCst) {
            return Err(env.stop_error(ctx, STOP_CANCELLED));
        }
        let now = Instant::now();
        if now >= end {
            break;
        }
        thread::park_timeout(CANCEL_POLL.min(end - now));
    }
    if wanted >= remaining {
        // The whole rest of the call was slept away.
        return Err(env.stop_error(ctx, STOP_TIMEOUT));
    }
    Ok(())
}

/// Native `sleep(ms)`.
pub fn register<'js>(
    ctx: &Ctx<'js>,
    natives: &Object<'js>,
    env: &Rc<HostEnv>,
) -> rquickjs::Result<()> {
    let env = env.clone();
    natives.set(
        "sleep",
        Function::new(ctx.clone(), move |ctx: Ctx<'js>, ms: f64| {
            sleep(&ctx, &env, ms)
        })?,
    )
}
