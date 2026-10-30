//! Per-job side channel for what a failed run must still return: console
//! lines, the first fetch failure and the changed storage map.
//!
//! The collector is created before the script runs, outside the panic guard,
//! and host functions write into it as they go. Every result, whatever its
//! status, takes its `logs`, `fetch_failure` and `storage_json` from here, so
//! a timeout, a memory error, a cancel or even a panic loses nothing that was
//! captured before it.

use std::sync::{Arc, Mutex, MutexGuard};

use super::host_console::LogBuffer;
use super::host_storage::Storage;
use crate::api::plugin_runtime::{PluginFetchFailure, PluginScriptResult, PluginScriptStatus};

#[derive(Default)]
struct Captured {
    logs: LogBuffer,
    fetch_failure: Option<PluginFetchFailure>,
    storage: Storage,
}

/// Shared handle; clones write to the same state.
#[derive(Clone, Default)]
pub struct Collector(Arc<Mutex<Captured>>);

impl Collector {
    pub fn new() -> Self {
        Self::default()
    }

    fn lock(&self) -> MutexGuard<'_, Captured> {
        // A panic while holding the lock leaves plain data behind; keep using it.
        self.0.lock().unwrap_or_else(|e| e.into_inner())
    }

    /// Appends one console line (cut and counted by the log buffer).
    pub fn push_log(&self, line: String) {
        self.lock().logs.push(line);
    }

    /// Records a fetch failure; only the first one of a call is kept.
    pub fn set_fetch_failure_once(&self, failure: PluginFetchFailure) {
        self.lock().fetch_failure.get_or_insert(failure);
    }

    /// Runs `f` on the call's storage copy.
    pub fn with_storage<R>(&self, f: impl FnOnce(&mut Storage) -> R) -> R {
        f(&mut self.lock().storage)
    }

    /// Copies everything captured so far into `result`.
    pub fn fill(&self, result: &mut PluginScriptResult) {
        let captured = self.lock();
        result.logs = captured.logs.lines();
        result.fetch_failure = captured.fetch_failure.clone();
        // A changed map is saved only when the script finished on its own; a
        // run that was stopped may have left it half written.
        result.storage_json = match result.status {
            PluginScriptStatus::Ok | PluginScriptStatus::ScriptError => {
                captured.storage.changed_json()
            }
            _ => None,
        };
    }
}
