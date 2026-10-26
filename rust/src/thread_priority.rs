//! Lowers the priority of background threads so they give way to playback
//! and the UI.

use std::sync::Once;

/// Raises the calling thread's nice value to at least `min_nice`. On Linux
/// nice is per thread and `PRIO_PROCESS` takes a thread id. A failure is
/// reported once through `report` (`what` names the threads) and otherwise
/// ignored: the work still gets done, only at normal priority. Each caller
/// owns its `Once`, so every kind of thread reports its own failure.
///
/// A niced thread can never be made normal again without privilege, so only
/// call this on threads that are dedicated to background work.
#[cfg(target_os = "linux")]
pub(crate) fn lower_thread_priority(min_nice: i32, report: &'static Once, what: &str) {
    // SAFETY: plain syscalls on the calling thread, no pointers involved.
    // getpriority can return -1 as a valid value, so errno is checked.
    let failed = unsafe {
        let tid = libc::gettid() as libc::id_t;
        *libc::__errno_location() = 0;
        let current = libc::getpriority(libc::PRIO_PROCESS, tid);
        if current == -1 && *libc::__errno_location() != 0 {
            true
        } else {
            libc::setpriority(libc::PRIO_PROCESS, tid, current.max(min_nice)) != 0
        }
    };
    if failed {
        report.call_once(|| {
            eprintln!(
                "kanaru: cannot lower the {what} threads' priority: {}",
                std::io::Error::last_os_error()
            );
        });
    }
}

/// Priorities are not changed off Linux.
#[cfg(not(target_os = "linux"))]
pub(crate) fn lower_thread_priority(_min_nice: i32, _report: &'static Once, _what: &str) {}

/// The calling thread's nice value, for tests that check a thread is niced.
#[cfg(target_os = "linux")]
pub(crate) fn current_nice() -> i32 {
    // SAFETY: plain syscall on the calling thread.
    unsafe { libc::getpriority(libc::PRIO_PROCESS, libc::gettid() as libc::id_t) }
}

#[cfg(not(target_os = "linux"))]
pub(crate) fn current_nice() -> i32 {
    0
}
