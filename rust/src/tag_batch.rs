//! Runs tag reading for a batch of files on a small dedicated thread pool.

use rayon::prelude::*;
use std::sync::LazyLock;

use crate::api::tags::TrackTags;
use crate::tag_reader::read_one;

/// Stack size for tag-reading threads. Parsers recurse on nested containers
/// (MP4 atoms, Ogg pages), and rayon's default stack is smaller than the
/// 8 MiB a normal main thread gets.
pub(crate) const WORKER_STACK_BYTES: usize = 8 * 1024 * 1024;

/// Number of tag threads for a machine with `cpus` hardware threads: half of
/// them, so a scan leaves room for playback and the UI, and at least two.
///
/// Each thread reads one file at a time. The cover pool uses the same count.
/// A cover thread holds every picture lofty read from its file (each at most
/// 16 MiB, `MAX_COVER_BYTES`) and, while it makes a thumbnail, a decode buffer
/// capped by [`MAX_DECODE_BYTES`](crate::cover_thumbnail::MAX_DECODE_BYTES)
/// plus the RGB copy made from it, which takes the peak to about 2x that limit
/// for typical RGB or RGBA covers and up to 4x for 8-bit gray ones. The worst
/// case is therefore this count times that sum, and it grows with the count.
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

/// Reads the tags of every file in `paths` in parallel. One entry per input
/// path, in the same order; a file that fails yields an entry with `error`
/// set and never fails the batch.
pub fn read_batch(paths: Vec<String>) -> Vec<TrackTags> {
    match &*POOL {
        Ok(pool) => pool.install(|| paths.par_iter().map(|p| read_one(p)).collect()),
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
