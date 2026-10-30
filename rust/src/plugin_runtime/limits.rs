//! Every limit of the plugin runtime in one place. `docs/lyrics-plugin-api.md`
//! ("Runtime and limits") mirrors this table.

use std::time::Duration;

/// Threads running JS at the same time.
pub const WORKER_THREADS: usize = 4;
/// Jobs that may wait for a free worker; the next one is `Busy`.
pub const QUEUE_CAPACITY: usize = 16;
/// Stack of every JS worker thread (and of the compile-check thread).
pub const THREAD_STACK_BYTES: usize = 8 * 1024 * 1024;
/// Script heap cap (QuickJS allocations).
pub const MEMORY_LIMIT_BYTES: usize = 32 * 1024 * 1024;
/// Script stack cap; far below the thread stack so QuickJS fails first, even
/// inside native recursion (`JSON.parse`, `String(nested array)`).
pub const SCRIPT_STACK_BYTES: usize = 1024 * 1024;
/// Wall time of one call.
pub const WALL_TIME: Duration = Duration::from_secs(15);
/// Largest `output_json`.
pub const MAX_OUTPUT_BYTES: usize = 2 * 1024 * 1024;
/// Longest `Response.error` message and thrown-error message kept, in characters.
pub const MAX_ERROR_MESSAGE_CHARS: usize = 1000;
/// Longest thrown-error stack kept, in bytes.
pub const MAX_ERROR_STACK_BYTES: usize = 16 * 1024;

/// The wall time of a call: the request's value capped by [`WALL_TIME`];
/// 0 means the full [`WALL_TIME`].
pub fn effective_wall_time(requested_ms: u32) -> Duration {
    if requested_ms == 0 {
        return WALL_TIME;
    }
    Duration::from_millis(u64::from(requested_ms)).min(WALL_TIME)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wall_time_is_capped_and_defaults() {
        assert_eq!(effective_wall_time(0), WALL_TIME);
        assert_eq!(effective_wall_time(200), Duration::from_millis(200));
        assert_eq!(effective_wall_time(u32::MAX), WALL_TIME);
    }

    #[test]
    fn script_stack_is_far_below_thread_stack() {
        assert!(SCRIPT_STACK_BYTES * 4 <= THREAD_STACK_BYTES);
    }
}
