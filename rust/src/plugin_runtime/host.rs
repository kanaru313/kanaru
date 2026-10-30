//! The host API a script sees besides `Response` and `load`: `fetch`, `sleep`,
//! `localConfig`, `localStorage`, `console`, `Log` and `Html`.
//!
//! Rust provides small natives (`host_*.rs`); `js/host_prelude.js` wraps them
//! into the script-facing objects and errors. The natives are handed to the
//! prelude as an argument and never become globals, so a script cannot reach
//! them directly.

use std::collections::HashMap;
use std::rc::Rc;
use std::sync::atomic::{AtomicBool, AtomicU8, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use rquickjs::{Ctx, Exception, Function, Object};

use super::collector::Collector;
use super::globals::eval_classic;
use super::host_budget::ByteBudget;
use super::host_callback::Answerer;
use super::{host_console, host_fetch, host_html, host_sleep, host_storage};

/// Why a run was stopped (set by the interrupt handler or a blocked host call).
pub const STOP_NONE: u8 = 0;
pub const STOP_CANCELLED: u8 = 1;
pub const STOP_TIMEOUT: u8 = 2;
/// A host function panicked; the run ends `internal`.
pub const STOP_INTERNAL: u8 = 3;

const HOST_PRELUDE: &str = include_str!("js/host_prelude.js");

/// What the host functions of one job share.
pub struct HostEnv {
    pub deadline: Instant,
    /// The job's cancel flag.
    pub cancel: Arc<AtomicBool>,
    /// Why the run was stopped; the first reason wins.
    pub stop: Arc<AtomicU8>,
    /// Rust-side bytes the host holds for the script (shared by every holder).
    pub budget: ByteBudget,
    pub collector: Collector,
    pub answerer: Answerer,
    /// Read-only `localConfig`.
    pub config: HashMap<String, String>,
    /// The plugin's stored map as JSON (empty text: nothing stored).
    pub storage_json: String,
}

impl HostEnv {
    /// Time left until the deadline.
    pub fn remaining(&self) -> Duration {
        self.deadline.saturating_duration_since(Instant::now())
    }

    /// Records why the run stops, unless a reason is already recorded.
    pub fn mark_stopped(&self, why: u8) {
        let _ = self
            .stop
            .compare_exchange(STOP_NONE, why, Ordering::SeqCst, Ordering::SeqCst);
    }

    /// Marks the run stopped and gives the exception that unwinds the script.
    /// A script can catch it, but the stop reason makes the result
    /// `cancelled` / `timeout` anyway, and every further host call throws again.
    pub fn stop_error<'js>(&self, ctx: &Ctx<'js>, why: u8) -> rquickjs::Error {
        self.mark_stopped(why);
        let message = if why == STOP_CANCELLED {
            "the call was cancelled"
        } else if why == STOP_INTERNAL {
            "internal error in a host function"
        } else {
            "the call ran out of time"
        };
        Exception::throw_message(ctx, message)
    }

    /// Why the call should stop now (cancelled, or out of time), without
    /// throwing: for code that holds a borrow and must not throw inside it.
    pub fn stop_reason(&self) -> Option<u8> {
        if self.cancel.load(Ordering::SeqCst) {
            Some(STOP_CANCELLED)
        } else if Instant::now() >= self.deadline {
            Some(STOP_TIMEOUT)
        } else {
            None
        }
    }

    /// Throws when the call was cancelled or its time is up.
    pub fn check_alive<'js>(&self, ctx: &Ctx<'js>) -> rquickjs::Result<()> {
        match self.stop_reason() {
            Some(why) => Err(self.stop_error(ctx, why)),
            None => Ok(()),
        }
    }
}

/// Installs the host API in the context.
pub fn install<'js>(ctx: &Ctx<'js>, env: HostEnv) -> rquickjs::Result<()> {
    let env = Rc::new(env);
    let natives = Object::new(ctx.clone())?;
    host_storage::register(ctx, &natives, &env)?;
    host_console::register(ctx, &natives, &env)?;
    host_fetch::register(ctx, &natives, &env)?;
    host_sleep::register(ctx, &natives, &env)?;
    host_html::register(ctx, &natives, &env)?;
    let init: Function = eval_classic(ctx, HOST_PRELUDE, "<runtime>")?
        .into_function()
        .ok_or_else(|| Exception::throw_message(ctx, "host prelude did not return a function"))?;
    init.call::<_, ()>((natives,))
}
