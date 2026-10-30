//! Per-job side channel for what a failed run must still return: console
//! lines, the first fetch failure and the changed storage map.
//!
//! The collector is created before the script runs, outside the panic guard,
//! and host functions write into it as they go. Every result, whatever its
//! status, takes its `logs`, `fetch_failure` and `storage_json` from here, so
//! a timeout, a memory error, a cancel or even a panic loses nothing that was
//! captured before it.

use std::sync::{Arc, Mutex, MutexGuard};

use crate::api::plugin_runtime::{PluginFetchFailure, PluginScriptResult};

#[derive(Default)]
struct Captured {
    logs: Vec<String>,
    fetch_failure: Option<PluginFetchFailure>,
    storage_json: Option<String>,
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

    /// Appends one console line.
    #[allow(dead_code)] // written by the console host API
    pub fn push_log(&self, line: String) {
        self.lock().logs.push(line);
    }

    /// Records a fetch failure; only the first one of a call is kept.
    #[allow(dead_code)] // written by the fetch host API
    pub fn set_fetch_failure_once(&self, failure: PluginFetchFailure) {
        self.lock().fetch_failure.get_or_insert(failure);
    }

    /// Records the whole new storage map.
    #[allow(dead_code)] // written by the storage host API
    pub fn set_storage_json(&self, json: String) {
        self.lock().storage_json = Some(json);
    }

    /// Copies everything captured so far into `result`.
    pub fn fill(&self, result: &mut PluginScriptResult) {
        let captured = self.lock();
        result.logs = captured.logs.clone();
        result.fetch_failure = captured.fetch_failure.clone();
        result.storage_json = captured.storage_json.clone();
    }
}
