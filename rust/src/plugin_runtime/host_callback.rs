//! The call from the JS thread to whoever answers fetches (Dart in the app, a
//! closure in Rust tests), with a wait that honours the cancel flag and the
//! job deadline.
//!
//! The answerer returns a future. For the Dart callback that is a
//! `DartFnFuture` that completes when Dart replies, from another thread. The
//! JS thread polls it itself and parks between polls, so no async runtime is
//! needed and no bridge worker blocks. The thread is woken by the future (via
//! `Wake`) or after [`CANCEL_POLL`], whichever comes first.

use std::cell::Cell;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{self, RecvTimeoutError, Sender};
use std::sync::{Arc, Once, OnceLock};
use std::task::{Context, Poll, Wake, Waker};
use std::thread;
use std::time::{Duration, Instant};

use flutter_rust_bridge::DartFnFuture;

use super::limits::CANCEL_POLL;
use crate::api::plugin_runtime::{PluginFetchOutcome, PluginFetchRequest, PluginFetchResponse};

/// Answers one fetch request. Called on the JS worker thread; must return
/// quickly with a future (the waiting is done by [`wait_for_answer`]).
pub type Answerer =
    Arc<dyn Fn(PluginFetchRequest) -> DartFnFuture<PluginFetchResponse> + Send + Sync>;

/// A response with no data for a failed outcome.
pub fn failed_response(outcome: PluginFetchOutcome) -> PluginFetchResponse {
    PluginFetchResponse {
        outcome,
        status: 0,
        url: String::new(),
        headers: Vec::new(),
        body: Vec::new(),
        retry_after_sec: None,
        sends: 0,
    }
}

/// The answerer of a run that has no network: every fetch fails with `network`.
pub fn no_network() -> Answerer {
    Arc::new(|_request| Box::pin(async { failed_response(PluginFetchOutcome::Network) }))
}

/// Most abandoned futures the drain thread waits on at once.
pub const MAX_LATE: usize = 256;
/// Longest the drain thread waits for one abandoned future (Dart's overall
/// timeout is 30 s, so a reply after this is not expected).
pub const MAX_LATE_AGE: Duration = Duration::from_secs(120);
const LATE_POLL: Duration = Duration::from_millis(50);

type Pending = DartFnFuture<PluginFetchResponse>;

thread_local! {
    /// True while this thread runs the callback: its panics are expected and silent.
    static QUIET: Cell<bool> = const { Cell::new(false) };
}

/// Installs (once) a panic hook that stays silent for [`QUIET`] threads and
/// otherwise calls the hook that was there before.
fn install_quiet_hook() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let previous = std::panic::take_hook();
        std::panic::set_hook(Box::new(move |info| {
            if !QUIET.with(Cell::get) {
                previous(info);
            }
        }));
    });
}

/// Runs `f` with panics silenced; the panic payload if it panicked.
pub(super) fn quietly_catching<T>(
    f: impl FnOnce() -> T,
) -> Result<T, Box<dyn std::any::Any + Send>> {
    install_quiet_hook();
    QUIET.with(|q| q.set(true));
    let result = catch_unwind(AssertUnwindSafe(f));
    QUIET.with(|q| q.set(false));
    result
}

/// Runs `f` with callback panics silenced; `None` if it panicked.
fn quietly<T>(f: impl FnOnce() -> T) -> Option<T> {
    quietly_catching(f).ok()
}

/// How the wait for an answer ended.
pub enum Waited {
    Answer(PluginFetchResponse),
    Cancelled,
    DeadlinePassed,
    /// The callback or its future panicked (Dart threw): treat as `network`.
    Failed,
}

struct UnparkWaker(thread::Thread);

impl Wake for UnparkWaker {
    fn wake(self: Arc<Self>) {
        self.0.unpark();
    }
}

/// Calls `answerer` and blocks the calling thread until the future completes,
/// `cancel` is set or `deadline` passes. An unfinished future is handed to the
/// late-answers drain, not dropped.
pub fn ask(
    answerer: &Answerer,
    request: PluginFetchRequest,
    cancel: &AtomicBool,
    deadline: Instant,
) -> Waited {
    let Some(mut future) = quietly(|| answerer(request)) else {
        return Waited::Failed;
    };
    let waker = Waker::from(Arc::new(UnparkWaker(thread::current())));
    let mut cx = Context::from_waker(&waker);
    let mut polled = false;
    loop {
        if cancel.load(Ordering::SeqCst) {
            if polled {
                hand_over_late(future);
            } else {
                // Never polled: the Dart call has not started and no reply
                // channel exists, so dropping is safe and starts nothing.
                let _ = quietly(|| drop(future));
            }
            return Waited::Cancelled;
        }
        polled = true;
        match quietly(|| std::future::Future::poll(future.as_mut(), &mut cx)) {
            None => {
                // A future that panicked is finished; never poll it again,
                // and leak it rather than run its destructor.
                std::mem::forget(future);
                return Waited::Failed;
            }
            Some(Poll::Ready(answer)) => return Waited::Answer(answer),
            Some(Poll::Pending) => {}
        }
        let now = Instant::now();
        if now >= deadline {
            hand_over_late(future);
            return Waited::DeadlinePassed;
        }
        thread::park_timeout(CANCEL_POLL.min(deadline - now));
    }
}

struct Late {
    future: Pending,
    since: Instant,
}

/// Gives an unfinished future to the drain thread (see the module docs).
fn hand_over_late(future: Pending) {
    static SENDER: OnceLock<Option<Sender<Late>>> = OnceLock::new();
    let sender = SENDER.get_or_init(|| {
        let (tx, rx) = mpsc::channel::<Late>();
        thread::Builder::new()
            .name("plugin-late-answers".to_owned())
            .spawn(move || drain_late(rx))
            .ok()
            .map(|_| tx)
    });
    let late = Late {
        future,
        since: Instant::now(),
    };
    match sender {
        Some(tx) => {
            if let Err(mpsc::SendError(late)) = tx.send(late) {
                std::mem::forget(late.future);
            }
        }
        None => std::mem::forget(late.future),
    }
}

/// Polls abandoned futures until they finish; the answers are discarded.
fn drain_late(rx: mpsc::Receiver<Late>) {
    let waker = Waker::noop();
    let mut cx = Context::from_waker(waker);
    let mut waiting: Vec<Late> = Vec::new();
    loop {
        let wait = if waiting.is_empty() {
            Duration::from_secs(3600)
        } else {
            LATE_POLL
        };
        match rx.recv_timeout(wait) {
            Ok(late) => {
                if waiting.len() >= MAX_LATE {
                    std::mem::forget(late.future);
                } else {
                    waiting.push(late);
                }
                while let Ok(late) = rx.try_recv() {
                    if waiting.len() >= MAX_LATE {
                        std::mem::forget(late.future);
                    } else {
                        waiting.push(late);
                    }
                }
            }
            Err(RecvTimeoutError::Timeout) => {}
            Err(RecvTimeoutError::Disconnected) => return,
        }
        let mut still = Vec::with_capacity(waiting.len());
        for mut late in waiting.drain(..) {
            match quietly(|| std::future::Future::poll(late.future.as_mut(), &mut cx)) {
                Some(Poll::Pending) if late.since.elapsed() < MAX_LATE_AGE => still.push(late),
                Some(Poll::Pending) => std::mem::forget(late.future),
                // Finished: drop the answer. Panicked: never touch it again.
                Some(Poll::Ready(_)) => {}
                None => std::mem::forget(late.future),
            }
        }
        waiting = still;
    }
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use super::*;

    fn answerer_of(f: impl Fn() -> Pending + Send + Sync + 'static) -> Answerer {
        Arc::new(move |_request| f())
    }

    fn request() -> PluginFetchRequest {
        PluginFetchRequest {
            method: "GET".to_owned(),
            url: "https://t.test/".to_owned(),
            headers: Vec::new(),
            body: Vec::new(),
            deadline_ms: 1000,
            max_sends: 10,
        }
    }

    #[test]
    fn a_ready_future_answers() {
        let a = answerer_of(|| Box::pin(async { failed_response(PluginFetchOutcome::Network) }));
        let cancel = AtomicBool::new(false);
        match ask(
            &a,
            request(),
            &cancel,
            Instant::now() + Duration::from_secs(5),
        ) {
            Waited::Answer(r) => assert_eq!(r.outcome, PluginFetchOutcome::Network),
            _ => panic!("expected an answer"),
        }
    }

    #[test]
    fn a_pending_future_ends_at_the_deadline_or_on_cancel() {
        let a = answerer_of(|| Box::pin(std::future::pending()));
        let cancel = AtomicBool::new(false);
        let started = Instant::now();
        assert!(matches!(
            ask(&a, request(), &cancel, started + Duration::from_millis(120)),
            Waited::DeadlinePassed
        ));
        assert!(started.elapsed() < Duration::from_secs(5));

        cancel.store(true, Ordering::SeqCst);
        assert!(matches!(
            ask(
                &a,
                request(),
                &cancel,
                Instant::now() + Duration::from_secs(60)
            ),
            Waited::Cancelled
        ));
    }

    #[test]
    fn a_cancel_before_the_first_poll_drops_the_lazy_future_unpolled() {
        use std::sync::atomic::AtomicUsize;
        struct Lazy(Arc<AtomicUsize>, Arc<AtomicBool>);
        impl std::future::Future for Lazy {
            type Output = PluginFetchResponse;
            fn poll(self: std::pin::Pin<&mut Self>, _: &mut Context<'_>) -> Poll<Self::Output> {
                self.0.fetch_add(1, Ordering::SeqCst);
                Poll::Pending
            }
        }
        impl Drop for Lazy {
            fn drop(&mut self) {
                self.1.store(true, Ordering::SeqCst);
            }
        }
        let (polls, dropped) = (
            Arc::new(AtomicUsize::new(0)),
            Arc::new(AtomicBool::new(false)),
        );
        let (p, d) = (polls.clone(), dropped.clone());
        let a = answerer_of(move || Box::pin(Lazy(p.clone(), d.clone())));
        let cancel = AtomicBool::new(true);
        assert!(matches!(
            ask(
                &a,
                request(),
                &cancel,
                Instant::now() + Duration::from_secs(60)
            ),
            Waited::Cancelled
        ));
        assert!(dropped.load(Ordering::SeqCst), "dropped on the spot");
        std::thread::sleep(Duration::from_millis(300));
        assert_eq!(
            polls.load(Ordering::SeqCst),
            0,
            "never polled, not even by the drain"
        );
    }

    #[test]
    fn a_panicking_call_or_poll_is_a_failure() {
        let cancel = AtomicBool::new(false);
        let end = Instant::now() + Duration::from_secs(5);
        let at_call = answerer_of(|| panic!("dart threw"));
        assert!(matches!(
            ask(&at_call, request(), &cancel, end),
            Waited::Failed
        ));
        let at_poll = answerer_of(|| Box::pin(async { panic!("dart threw in poll") }));
        assert!(matches!(
            ask(&at_poll, request(), &cancel, end),
            Waited::Failed
        ));
    }
}
