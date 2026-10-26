//! Shared state of one waveform job, and the hooks tests use to hold a
//! decode at a known point.
//!
//! The hooks are public and hidden from docs because the integration tests
//! link the library like any other crate. They cost one atomic load per
//! packet while no test has installed one.

use std::collections::HashMap;
use std::path::Path;
use std::sync::atomic::{AtomicBool, AtomicI32, AtomicU64, AtomicUsize, Ordering};
use std::sync::{Arc, Condvar, Mutex, PoisonError};
use std::time::{Duration, Instant};

/// What the job thread and the thread waiting for it share.
#[derive(Default)]
pub struct JobControl {
    cancelled: AtomicBool,
    /// Packets seen so far; the waiting side treats a value that stops
    /// changing as a stalled job.
    progress: AtomicU64,
    gate: Mutex<Option<Arc<DecodeGate>>>,
}

impl JobControl {
    pub fn cancel(&self) {
        self.cancelled.store(true, Ordering::Relaxed);
    }

    pub fn cancelled(&self) -> bool {
        self.cancelled.load(Ordering::Relaxed)
    }

    pub fn progress(&self) -> u64 {
        self.progress.load(Ordering::Relaxed)
    }

    /// Called by the decode loop for every packet read: the stall heartbeat,
    /// and the place a test gate holds the decode.
    pub(crate) fn packet_read(&self) {
        let packets = self.progress.fetch_add(1, Ordering::Relaxed) + 1;
        if GATES_INSTALLED.load(Ordering::Relaxed) == 0 {
            return;
        }
        let gate = lock(&self.gate).clone();
        if let Some(gate) = gate {
            gate.pass(packets);
        }
    }

    /// Picks up the test gate installed for `path`, if any.
    pub(crate) fn attach_gate_for(&self, path: &Path) {
        if GATES_INSTALLED.load(Ordering::Relaxed) > 0 {
            let found = lock(&GATES)
                .iter()
                .find(|(p, _)| p == path)
                .map(|(_, gate)| gate.clone());
            *lock(&self.gate) = found;
        }
    }
}

static GATES: Mutex<Vec<(std::path::PathBuf, Arc<DecodeGate>)>> = Mutex::new(Vec::new());
static GATES_INSTALLED: AtomicUsize = AtomicUsize::new(0);

/// Holds the decode of one file after a number of packets until released.
/// Install it with [`install_decode_gate`] before loading the file.
pub struct DecodeGate {
    after_packets: u64,
    released: Mutex<bool>,
    changed: Condvar,
    reached: AtomicBool,
    nice: AtomicI32,
}

impl DecodeGate {
    fn pass(&self, packets: u64) {
        if packets < self.after_packets {
            return;
        }
        self.nice
            .store(crate::thread_priority::current_nice(), Ordering::Relaxed);
        self.reached.store(true, Ordering::Release);
        let mut released = lock(&self.released);
        while !*released {
            released = self
                .changed
                .wait(released)
                .unwrap_or_else(PoisonError::into_inner);
        }
    }

    /// Waits until a decode is held at the gate; `false` after `timeout`.
    pub fn wait_reached(&self, timeout: Duration) -> bool {
        let start = Instant::now();
        while !self.reached.load(Ordering::Acquire) {
            if start.elapsed() > timeout {
                return false;
            }
            std::thread::sleep(Duration::from_millis(2));
        }
        true
    }

    /// Lets held and future decodes through.
    pub fn release(&self) {
        *lock(&self.released) = true;
        self.changed.notify_all();
    }

    /// Nice value of the thread that was held at the gate.
    pub fn nice_of_held_thread(&self) -> i32 {
        self.nice.load(Ordering::Relaxed)
    }
}

/// Removes the gate when dropped, releasing anything still held by it.
pub struct GateGuard {
    path: std::path::PathBuf,
    pub gate: Arc<DecodeGate>,
}

impl Drop for GateGuard {
    fn drop(&mut self) {
        self.gate.release();
        let mut gates = lock(&GATES);
        let before = gates.len();
        gates.retain(|(p, _)| p != &self.path);
        GATES_INSTALLED.fetch_sub(before - gates.len(), Ordering::Relaxed);
    }
}

/// Holds the decode of `path` once `after_packets` packets were read, until
/// the gate is released or the guard dropped.
#[doc(hidden)]
pub fn install_decode_gate(path: &Path, after_packets: u64) -> GateGuard {
    let gate = Arc::new(DecodeGate {
        after_packets,
        released: Mutex::new(false),
        changed: Condvar::new(),
        reached: AtomicBool::new(false),
        nice: AtomicI32::new(0),
    });
    lock(&GATES).push((path.to_path_buf(), gate.clone()));
    GATES_INSTALLED.fetch_add(1, Ordering::Relaxed);
    GateGuard {
        path: path.to_path_buf(),
        gate,
    }
}

static DECODES: Mutex<Option<HashMap<String, usize>>> = Mutex::new(None);

/// Counts one decode for the cache folder `cache_dir`.
pub(crate) fn note_decode(cache_dir: &str) {
    *lock(&DECODES)
        .get_or_insert_with(HashMap::new)
        .entry(cache_dir.to_owned())
        .or_insert(0) += 1;
}

/// How many files were decoded (not served from the cache) with `cache_dir`
/// as their cache folder; keyed by folder so parallel tests do not mix.
#[doc(hidden)]
pub fn decode_count(cache_dir: &str) -> usize {
    lock(&DECODES)
        .as_ref()
        .and_then(|m| m.get(cache_dir).copied())
        .unwrap_or(0)
}

fn lock<T>(mutex: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(PoisonError::into_inner)
}
