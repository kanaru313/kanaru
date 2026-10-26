//! Runs one waveform job: registry of job ids, the niced worker thread, and
//! the wait that frees the caller on cancel, stall or a dead thread.
//!
//! A read can block forever on a mount that stopped answering, so the work
//! never runs on the bridge's worker. It runs on a thread of its own that the
//! caller waits for in slices of 100 ms; a caller that gives up leaves the
//! stuck thread behind (like the lyrics reader), and at most two such threads
//! live at once.

use std::collections::HashMap;
use std::fs::File;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::Path;
use std::sync::atomic::{AtomicU32, AtomicUsize, Ordering};
use std::sync::mpsc::{self, RecvTimeoutError};
use std::sync::{Arc, LazyLock, Mutex, Once, PoisonError};
use std::time::{Duration, Instant};

use crate::api::waveform::{TrackWaveform, WaveformStatus};
use crate::tag_batch::WORKER_STACK_BYTES;
use crate::thread_priority::lower_thread_priority;
use crate::waveform_cache::{lookup_or_store, CacheEntry, CacheSlot};
use crate::waveform_cache_sweep::{claim, SweepTicket};
use crate::waveform_control::{note_decode, JobControl};
use crate::waveform_decode::{decode_open_file, open_audio, DecodeOutcome, Failure};

/// Nice value the waveform threads run at, at least: decoding a whole file
/// is background work and must give way to playback and the UI.
const WAVEFORM_NICE: i32 = 10;
/// How long the caller waits between checks for cancel and stall.
const POLL: Duration = Duration::from_millis(100);
/// Time without a decoded packet after which a job counts as stalled.
const STALL_LIMIT: Duration = Duration::from_secs(10);
/// Waveform threads alive at once, finished or abandoned by their caller.
const MAX_THREADS: usize = 2;

static NEXT_JOB: AtomicU32 = AtomicU32::new(1);
static JOBS: Mutex<Option<HashMap<u32, Arc<JobControl>>>> = Mutex::new(None);
static DEFAULT_ENV: LazyLock<JobEnv> = LazyLock::new(|| JobEnv::new(STALL_LIMIT, MAX_THREADS));

/// The limits a job runs under; tests build their own so a held or stalled
/// job in one test cannot starve another.
pub struct JobEnv {
    stall: Duration,
    max_threads: usize,
    live: Arc<AtomicUsize>,
}

impl JobEnv {
    #[doc(hidden)]
    pub fn new(stall: Duration, max_threads: usize) -> Self {
        Self {
            stall,
            max_threads,
            live: Arc::default(),
        }
    }

    /// Waveform threads of this environment still running.
    #[doc(hidden)]
    pub fn live_threads(&self) -> usize {
        self.live.load(Ordering::SeqCst)
    }
}

/// Decrements the live-thread count when the job thread ends, however it ends.
struct LiveGuard(Arc<AtomicUsize>);

impl Drop for LiveGuard {
    fn drop(&mut self) {
        self.0.fetch_sub(1, Ordering::SeqCst);
    }
}

fn with_jobs<R>(f: impl FnOnce(&mut HashMap<u32, Arc<JobControl>>) -> R) -> R {
    let mut jobs = JOBS.lock().unwrap_or_else(PoisonError::into_inner);
    f(jobs.get_or_insert_with(HashMap::new))
}

/// A new job id, registered so it can be cancelled before it starts.
pub fn begin_job() -> u32 {
    let job = NEXT_JOB.fetch_add(1, Ordering::Relaxed);
    with_jobs(|jobs| jobs.insert(job, Arc::default()));
    job
}

/// Cancels job `job`; unknown or finished ids do nothing.
pub fn cancel_job(job: u32) {
    if let Some(control) = with_jobs(|jobs| jobs.get(&job).cloned()) {
        control.cancel();
    }
}

/// [`load`] under the production limits.
pub fn load_default(path: &str, cache_dir: &str, job: u32) -> TrackWaveform {
    load(&DEFAULT_ENV, path, cache_dir, job)
}

/// Runs job `job` for the file at `path`; see `api::waveform::load_waveform`.
#[doc(hidden)]
pub fn load(env: &JobEnv, path: &str, cache_dir: &str, job: u32) -> TrackWaveform {
    let Some(control) = with_jobs(|jobs| jobs.get(&job).cloned()) else {
        return with_status(WaveformStatus::Busy);
    };
    let result = run_on_thread(env, path, cache_dir, &control);
    with_jobs(|jobs| jobs.remove(&job));
    result
}

fn run_on_thread(
    env: &JobEnv,
    path: &str,
    cache_dir: &str,
    control: &Arc<JobControl>,
) -> TrackWaveform {
    if control.cancelled() {
        return with_status(WaveformStatus::Cancelled);
    }
    if env.live.fetch_add(1, Ordering::SeqCst) >= env.max_threads {
        env.live.fetch_sub(1, Ordering::SeqCst);
        return with_status(WaveformStatus::Busy);
    }
    let guard = LiveGuard(env.live.clone());
    let (sender, receiver) = mpsc::channel();
    let (path, cache_dir, thread_control) =
        (path.to_owned(), cache_dir.to_owned(), control.clone());
    let spawned = std::thread::Builder::new()
        .name("kanaru-waveform".to_owned())
        .stack_size(WORKER_STACK_BYTES)
        .spawn(move || {
            let (result, ticket) = catch_unwind(AssertUnwindSafe(|| {
                job_thread(&path, &cache_dir, &thread_control)
            }))
            .unwrap_or_else(|_| (with_status(WaveformStatus::Busy), None));
            // Free the thread slot before the caller can see the result, so a
            // job started right after this one is not refused for it.
            drop(guard);
            // The caller may have stopped waiting; nothing to do then.
            let _ = sender.send(result);
            // The cache sweep comes last, so the result never waits for it.
            if let Some(ticket) = ticket {
                let _ = catch_unwind(AssertUnwindSafe(|| ticket.run()));
            }
        });
    if spawned.is_err() {
        return with_status(WaveformStatus::Busy);
    }
    wait_for(&receiver, control, env.stall)
}

/// Waits for the thread's result, giving up on cancel, on a thread that died
/// without a result, and on a decode that stopped making progress.
fn wait_for(
    receiver: &mpsc::Receiver<TrackWaveform>,
    control: &JobControl,
    stall: Duration,
) -> TrackWaveform {
    let (mut seen, mut since) = (control.progress(), Instant::now());
    loop {
        match receiver.recv_timeout(POLL) {
            Ok(result) => return result,
            Err(RecvTimeoutError::Disconnected) => return with_status(WaveformStatus::Busy),
            Err(RecvTimeoutError::Timeout) => {}
        }
        if control.cancelled() {
            return with_status(WaveformStatus::Cancelled);
        }
        let progress = control.progress();
        if progress != seen {
            (seen, since) = (progress, Instant::now());
        } else if since.elapsed() >= stall {
            return with_status(WaveformStatus::Busy);
        }
    }
}

/// The work of a job: cache lookup, decode, cache write. The ticket, when
/// there is one, is a cache sweep for the caller to run after the result is
/// sent.
fn job_thread(
    path: &str,
    cache_dir: &str,
    control: &JobControl,
) -> (TrackWaveform, Option<SweepTicket>) {
    static PRIORITY_REPORTED: Once = Once::new();
    lower_thread_priority(WAVEFORM_NICE, &PRIORITY_REPORTED, "waveform");

    let path = Path::new(path);
    // One open handle serves the type check, the cache key and the decode, so
    // the file cannot change between them and a FIFO is never waited on.
    let Ok((file, meta)) = open_audio(path) else {
        return (with_status(WaveformStatus::Busy), None);
    };
    control.attach_gate_for(path);
    let slot = CacheSlot::new(cache_dir, path, &meta);
    let result = lookup_or_store(
        slot.as_ref(),
        |entry| match entry {
            CacheEntry::Levels {
                levels,
                frames,
                sample_rate,
            } => ready(levels, frames, sample_rate),
            CacheEntry::Negative => with_status(WaveformStatus::Failed),
        },
        || {
            if control.cancelled() {
                return (with_status(WaveformStatus::Cancelled), None);
            }
            note_decode(cache_dir);
            decode_for_cache(path, file, control)
        },
    );
    let ticket = (!cache_dir.is_empty())
        .then(|| claim(Path::new(cache_dir)))
        .flatten();
    (result, ticket)
}

/// Decodes `file` and pairs the result with the cache entry it earns: levels
/// for a drawable waveform, a negative entry for a stream that is broken for
/// good, nothing for anything that may pass or is cheap to repeat.
fn decode_for_cache(
    path: &Path,
    file: File,
    control: &JobControl,
) -> (TrackWaveform, Option<CacheEntry>) {
    match decode_open_file(path, file, control) {
        DecodeOutcome::Ready {
            levels,
            frames,
            sample_rate,
        } => {
            // A clip too short to draw is cheap to decode again.
            let entry = (!levels.is_empty()).then(|| CacheEntry::Levels {
                levels: levels.clone(),
                frames,
                sample_rate,
            });
            (ready(levels, frames, sample_rate), entry)
        }
        DecodeOutcome::Failed(Failure::Broken(_)) => (
            with_status(WaveformStatus::Failed),
            Some(CacheEntry::Negative),
        ),
        DecodeOutcome::Failed(Failure::Io) => (with_status(WaveformStatus::Busy), None),
        DecodeOutcome::Unsupported => (with_status(WaveformStatus::Unsupported), None),
        DecodeOutcome::Cancelled => (with_status(WaveformStatus::Cancelled), None),
    }
}

fn ready(levels: Vec<u8>, frames: u64, sample_rate: u32) -> TrackWaveform {
    let millis = frames.saturating_mul(1000) / u64::from(sample_rate.max(1));
    TrackWaveform {
        status: WaveformStatus::Ready,
        levels,
        duration_ms: u32::try_from(millis).unwrap_or(u32::MAX),
    }
}

fn with_status(status: WaveformStatus) -> TrackWaveform {
    TrackWaveform {
        status,
        levels: Vec::new(),
        duration_ms: 0,
    }
}
