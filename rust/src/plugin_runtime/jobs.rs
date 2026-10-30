//! Job id registry: id -> cancel flag.
//!
//! Lifecycle of an id:
//! - `begin` registers it (not started).
//! - `cancel` before the run was claimed removes the entry, so the later
//!   `claim` finds nothing and the run is `Cancelled` at once (nothing leaks
//!   even if Dart never runs the cancelled job).
//! - `claim` marks it started and hands out a guard with the flag; `cancel`
//!   now only sets the flag. Dropping the guard removes the entry, so a late
//!   cancel of a finished id does nothing.

use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::{Arc, Mutex, MutexGuard, OnceLock};

struct Entry {
    cancel: Arc<AtomicBool>,
    started: bool,
}

pub struct JobRegistry {
    next: AtomicU32,
    entries: Mutex<HashMap<u32, Entry>>,
}

/// A claimed job. Dropping it forgets the id.
pub struct JobGuard<'a> {
    registry: &'a JobRegistry,
    id: u32,
    cancel: Arc<AtomicBool>,
}

impl JobRegistry {
    pub fn new() -> Self {
        Self {
            next: AtomicU32::new(1),
            entries: Mutex::new(HashMap::new()),
        }
    }

    fn lock(&self) -> MutexGuard<'_, HashMap<u32, Entry>> {
        // A poisoned lock only means another thread panicked; the map is still valid.
        self.entries.lock().unwrap_or_else(|e| e.into_inner())
    }

    pub fn begin(&self) -> u32 {
        let id = self.next.fetch_add(1, Ordering::Relaxed);
        self.lock().insert(
            id,
            Entry {
                cancel: Arc::new(AtomicBool::new(false)),
                started: false,
            },
        );
        id
    }

    pub fn cancel(&self, id: u32) {
        let mut entries = self.lock();
        let Some(entry) = entries.get(&id) else {
            return;
        };
        if entry.started {
            entry.cancel.store(true, Ordering::SeqCst);
        } else {
            entries.remove(&id);
        }
    }

    /// Marks `id` started. `None` for an unknown, cancelled or already claimed id.
    pub fn claim(&self, id: u32) -> Option<JobGuard<'_>> {
        let mut entries = self.lock();
        let entry = entries.get_mut(&id)?;
        if entry.started {
            return None;
        }
        entry.started = true;
        Some(JobGuard {
            registry: self,
            id,
            cancel: entry.cancel.clone(),
        })
    }

    #[cfg(test)]
    pub fn len(&self) -> usize {
        self.lock().len()
    }
}

impl JobGuard<'_> {
    pub fn cancel_flag(&self) -> Arc<AtomicBool> {
        self.cancel.clone()
    }
}

impl Drop for JobGuard<'_> {
    fn drop(&mut self) {
        self.registry.lock().remove(&self.id);
    }
}

pub fn registry() -> &'static JobRegistry {
    static REGISTRY: OnceLock<JobRegistry> = OnceLock::new();
    REGISTRY.get_or_init(JobRegistry::new)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ids_rise_and_claim_gives_the_flag() {
        let r = JobRegistry::new();
        let (a, b) = (r.begin(), r.begin());
        assert!(b > a);
        let guard = r.claim(a).expect("claim");
        assert!(!guard.cancel_flag().load(Ordering::SeqCst));
        assert!(r.claim(a).is_none(), "an id runs once");
        drop(guard);
        assert_eq!(r.len(), 1);
    }

    #[test]
    fn cancel_before_start_removes_the_entry() {
        let r = JobRegistry::new();
        for _ in 0..100 {
            let id = r.begin();
            r.cancel(id);
            assert!(r.claim(id).is_none(), "a cancelled id cannot be claimed");
        }
        assert_eq!(r.len(), 0);
    }

    #[test]
    fn cancel_while_running_sets_the_flag_and_end_forgets_the_id() {
        let r = JobRegistry::new();
        let id = r.begin();
        let guard = r.claim(id).unwrap();
        r.cancel(id);
        assert!(guard.cancel_flag().load(Ordering::SeqCst));
        assert_eq!(r.len(), 1);
        drop(guard);
        assert_eq!(r.len(), 0);
        r.cancel(id); // late cancel: nothing happens
        assert_eq!(r.len(), 0);
    }

    #[test]
    fn unknown_id_is_not_claimable() {
        let r = JobRegistry::new();
        assert!(r.claim(12345).is_none());
        r.cancel(12345);
    }
}
