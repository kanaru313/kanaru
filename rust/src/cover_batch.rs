//! Finds the covers of a batch of files and caches their thumbnails, without
//! reading tags, on a low-priority thread pool of its own.

use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::Path;
use std::sync::{LazyLock, Once};

use rayon::prelude::*;

use crate::api::tags::{CoverStatus, TrackCover};
use crate::cover_cache::CoverSink;
use crate::tag_batch::{thread_count, WORKER_STACK_BYTES};
use crate::tag_reader::{embedded_pictures_result, CoverReadError};
use crate::thread_priority::lower_thread_priority;

/// Nice value the cover threads run at, at least: making thumbnails is
/// background work and should give way to playback and the UI, without
/// starving under normal desktop load.
const COVER_NICE: i32 = 10;

/// Same size and stack as the tag pool, but separate: its threads are
/// niced, and a niced thread can never be made normal again without
/// privilege. `Err` holds why it could not start.
static COVER_POOL: LazyLock<Result<rayon::ThreadPool, String>> = LazyLock::new(|| {
    let threads = thread_count(std::thread::available_parallelism().map_or(1, usize::from));
    rayon::ThreadPoolBuilder::new()
        .num_threads(threads)
        .stack_size(WORKER_STACK_BYTES)
        .thread_name(|i| format!("kanaru-covers-{i}"))
        .start_handler(|_| {
            static REPORTED: Once = Once::new();
            lower_thread_priority(COVER_NICE, &REPORTED, "cover");
        })
        .build()
        .map_err(|e| format!("cannot start cover threads: {e}"))
});

/// Finds the cover of every file in `paths` and makes sure its thumbnail is
/// in `sink`'s folder. One entry per input path, in the same order; a file
/// that fails gives [`CoverStatus::Failed`] and never fails the batch.
pub fn read_covers(paths: Vec<String>, sink: &CoverSink) -> Vec<TrackCover> {
    match &*COVER_POOL {
        Ok(pool) => pool.install(|| {
            paths
                .into_par_iter()
                .map(|path| {
                    let (cover, status) = cover_for(&path, sink);
                    TrackCover {
                        path,
                        cover,
                        status,
                    }
                })
                .collect()
        }),
        Err(reason) => {
            report_pool_failure(reason);
            paths
                .into_iter()
                .map(|path| TrackCover {
                    path,
                    cover: None,
                    status: CoverStatus::Failed,
                })
                .collect()
        }
    }
}

/// Runs `work` on the cover threads, so it gives way to playback and the UI
/// like the thumbnails do. When the threads could not start it runs on the
/// calling thread instead.
pub(crate) fn in_cover_pool<R: Send>(work: impl FnOnce() -> R + Send) -> R {
    match &*COVER_POOL {
        Ok(pool) => pool.install(work),
        Err(reason) => {
            report_pool_failure(reason);
            work()
        }
    }
}

/// Reports once why the cover threads could not start; every cover then
/// fails, and the reason would otherwise be lost.
fn report_pool_failure(reason: &str) {
    use std::sync::Once;
    static REPORTED: Once = Once::new();
    REPORTED.call_once(|| eprintln!("kanaru: {reason}"));
}

/// The cover of `path`: the same sources and keys as the tag scan. A file
/// that is gone or not a regular file, a picture read that may pass, a
/// folder that cannot be listed, a sidecar image that cannot be read or a
/// crash give [`CoverStatus::Failed`]
/// (keep what is stored, try again later); [`CoverStatus::None`] only when
/// every source was checked.
fn cover_for(path: &str, sink: &CoverSink) -> (Option<String>, CoverStatus) {
    catch_unwind(AssertUnwindSafe(|| {
        let embedded = match embedded_pictures_result(path) {
            Ok(pictures) => pictures,
            Err(CoverReadError::Transient) => return (None, CoverStatus::Failed),
            // Pictures that cannot be parsed count as absent; sidecar images
            // beside the file still apply.
            Err(CoverReadError::Permanent) => Vec::new(),
        };
        sink.resolve(Path::new(path), embedded)
    }))
    .unwrap_or((None, CoverStatus::Failed))
}

#[cfg(all(test, target_os = "linux"))]
mod tests {
    use super::{COVER_NICE, COVER_POOL};

    #[test]
    fn cover_threads_run_at_a_lower_priority() {
        let pool = COVER_POOL.as_ref().expect("pool starts");
        let nice = pool.install(|| {
            // SAFETY: plain syscall on the calling thread.
            unsafe { libc::getpriority(libc::PRIO_PROCESS, libc::gettid() as libc::id_t) }
        });
        assert!(nice >= COVER_NICE, "nice {nice}");
    }
}
