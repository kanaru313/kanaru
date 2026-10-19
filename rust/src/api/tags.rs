//! Tag reading API exposed to Dart.

use rayon::prelude::*;
use std::sync::LazyLock;

use crate::tag_reader::read_one;

/// Stack size for tag-reading threads. Parsers recurse on nested containers
/// (MP4 atoms, Ogg pages), and rayon's default stack is smaller than the
/// 8 MiB a normal main thread gets.
const WORKER_STACK_BYTES: usize = 8 * 1024 * 1024;

/// Dedicated pool so tag reading never competes with other rayon users and
/// always runs with [`WORKER_STACK_BYTES`]. `Err` holds why it could not start.
static POOL: LazyLock<Result<rayon::ThreadPool, String>> = LazyLock::new(|| {
    rayon::ThreadPoolBuilder::new()
        .stack_size(WORKER_STACK_BYTES)
        .thread_name(|i| format!("kanaru-tags-{i}"))
        .build()
        .map_err(|e| format!("cannot start tag reader threads: {e}"))
});

/// Tags and audio properties of one file. Flat on purpose so flutter_rust_bridge
/// generates a plain Dart class. A field is `None` when the file does not say.
/// When [`error`](Self::error) is set the file could not be read and every
/// other field except [`path`](Self::path) is `None`.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct TrackTags {
    /// The path as given to [`read_tags_batch`].
    pub path: String,
    pub title: Option<String>,
    /// Every artist of the track joined with `"; "`.
    pub artist: Option<String>,
    pub album: Option<String>,
    pub album_artist: Option<String>,
    pub track_no: Option<u32>,
    pub track_total: Option<u32>,
    pub disc_no: Option<u32>,
    pub disc_total: Option<u32>,
    /// Four-digit year taken from the recording date.
    pub year: Option<u32>,
    pub genre: Option<String>,
    pub composer: Option<String>,
    pub comment: Option<String>,
    pub duration_ms: Option<i64>,
    /// Overall bitrate in kbps.
    pub bitrate: Option<u32>,
    pub sample_rate: Option<u32>,
    pub bit_depth: Option<u8>,
    pub channels: Option<u8>,
    /// Why the file could not be read; `None` on success.
    pub error: Option<String>,
}

/// Reads the tags of every file in `paths`, in parallel.
///
/// The result has exactly one entry per input path, in the same order. A file
/// that fails to read yields an entry with `error` set; it never fails the
/// batch.
pub fn read_tags_batch(paths: Vec<String>) -> Vec<TrackTags> {
    match &*POOL {
        Ok(pool) => pool.install(|| paths.par_iter().map(|p| read_one(p)).collect()),
        Err(reason) => paths
            .into_iter()
            .map(|path| TrackTags::failed(path, reason.clone()))
            .collect(),
    }
}

impl TrackTags {
    /// An entry for a file that could not be read.
    pub fn failed(path: String, error: String) -> Self {
        Self {
            path,
            error: Some(error),
            ..Self::default()
        }
    }
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
