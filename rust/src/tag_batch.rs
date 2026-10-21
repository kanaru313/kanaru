//! Runs tag reading for a batch of files on a small dedicated thread pool.

use rayon::prelude::*;
use std::sync::LazyLock;

use crate::api::tags::TrackTags;
use crate::cover_cache::CoverSink;
use crate::tag_reader::read_one;

/// Stack size for tag-reading threads. Parsers recurse on nested containers
/// (MP4 atoms, Ogg pages), and rayon's default stack is smaller than the
/// 8 MiB a normal main thread gets.
pub(crate) const WORKER_STACK_BYTES: usize = 8 * 1024 * 1024;

/// Number of tag threads for a machine with `cpus` hardware threads: half of
/// them, so a scan leaves room for playback and the UI, and at least two.
///
/// Each thread reads one file at a time. With covers on, lofty holds every
/// picture of that file in memory and a thumbnail decode may take up to
/// [`MAX_DECODE_BYTES`](crate::cover_thumbnail::MAX_DECODE_BYTES), so peak
/// memory grows with this count.
pub(crate) fn thread_count(cpus: usize) -> usize {
    (cpus / 2).max(2)
}

/// Dedicated pool so tag reading never competes with other rayon users and
/// always runs with [`WORKER_STACK_BYTES`]. `Err` holds why it could not start.
static POOL: LazyLock<Result<rayon::ThreadPool, String>> = LazyLock::new(|| {
    let threads = thread_count(std::thread::available_parallelism().map_or(1, usize::from));
    rayon::ThreadPoolBuilder::new()
        .num_threads(threads)
        .stack_size(WORKER_STACK_BYTES)
        .thread_name(|i| format!("kanaru-tags-{i}"))
        .build()
        .map_err(|e| format!("cannot start tag reader threads: {e}"))
});

/// Reads every file in `paths` in parallel, finding covers when `covers` is
/// given. One entry per input path, in the same order; a file that fails
/// yields an entry with `error` set and never fails the batch.
pub fn read_batch(paths: Vec<String>, covers: Option<&CoverSink>) -> Vec<TrackTags> {
    match &*POOL {
        Ok(pool) => pool.install(|| paths.par_iter().map(|p| read_one(p, covers)).collect()),
        Err(reason) => paths
            .into_iter()
            .map(|path| TrackTags::failed(path, reason.clone()))
            .collect(),
    }
}

#[cfg(test)]
mod tests {
    use super::thread_count;

    #[test]
    fn uses_half_the_cpus_and_at_least_two() {
        for (cpus, threads) in [(1, 2), (2, 2), (3, 2), (8, 4), (16, 8)] {
            assert_eq!(thread_count(cpus), threads, "{cpus} cpus");
        }
    }
}
