//! Tag reading API exposed to Dart.

use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::Path;
use std::sync::Arc;

use crate::cover_art::{first_source, list_images, read_bounded, validate_header, Attempt};
use crate::cover_batch::read_covers;
use crate::cover_cache::CoverSink;
use crate::cover_decode_limits::decode_fits;
use crate::tag_batch::read_batch;
use crate::tag_reader::embedded_pictures;

/// What happened when looking for a file's cover, in [`read_covers_batch`].
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum CoverStatus {
    /// Covers were not requested (empty cover folder).
    #[default]
    Skipped,
    /// A cover was found and its thumbnail is in the cache.
    Found,
    /// Every source was checked and none holds a usable image. Reading again
    /// gives the same answer.
    None,
    /// Something went wrong that may pass (the cache could not be written, the
    /// cover code crashed). Worth trying again on the next scan.
    Failed,
}

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

/// Reads the tags of every file in `paths`, in parallel. Pictures are not
/// loaded; covers come from [`read_covers_batch`].
///
/// The result has exactly one entry per input path, in the same order. A file
/// that fails to read yields an entry with `error` set; it never fails the
/// batch.
pub fn read_tags_batch(paths: Vec<String>) -> Vec<TrackTags> {
    read_batch(paths)
}

/// The cover of one file, from [`read_covers_batch`].
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct TrackCover {
    /// The path as given to [`read_covers_batch`].
    pub path: String,
    /// Cache key of the cover thumbnail, `<ab>/<hash>.jpg` relative to the
    /// cover folder; `hash` is the blake3 of the original image bytes. Set
    /// only when [`status`](Self::status) is [`CoverStatus::Found`].
    pub cover: Option<String>,
    pub status: CoverStatus,
}

/// Finds the cover of every file in `paths` and makes sure its thumbnail is
/// in `cover_dir`, in parallel on low-priority threads. Tags are not read.
///
/// `cover_dir` is the thumbnail folder (size included, e.g.
/// `.../covers/512`). The result has exactly one entry per input path, in the
/// same order. A file that is
/// gone, not a regular file, or whose cover could not be read for a reason
/// that may pass gives [`CoverStatus::Failed`]; [`CoverStatus::None`] means
/// every source was checked. When `cover_dir` is empty nothing is looked for
/// and every entry is [`CoverStatus::Skipped`]. Image bytes never cross to
/// Dart.
pub fn read_covers_batch(paths: Vec<String>, cover_dir: String) -> Vec<TrackCover> {
    if cover_dir.is_empty() {
        return paths
            .into_iter()
            .map(|path| TrackCover {
                path,
                ..TrackCover::default()
            })
            .collect();
    }
    read_covers(paths, &CoverSink::new(cover_dir))
}

/// The original bytes of the cover of the audio file at `path`, chosen the
/// same way the scan chooses (embedded first, then sidecar images), for views
/// that need more than the thumbnail. Nothing is decoded or written to disk.
/// `None` when the file has no usable cover or cannot be read.
pub fn read_original_cover(path: String) -> Option<Vec<u8>> {
    catch_unwind(AssertUnwindSafe(|| {
        let audio = Path::new(&path);
        if !std::fs::metadata(audio).is_ok_and(|m| m.is_file()) {
            return None;
        }
        // The scan decodes what it shows; a source it would refuse for its
        // decode limits is skipped here too, so both pick the same cover.
        let usable = |bytes: Vec<u8>| match validate_header(&bytes) {
            Some(format) if decode_fits(&bytes, format) => Attempt::Take(bytes),
            _ => Attempt::Next,
        };
        first_source(
            audio,
            embedded_pictures(&path),
            |dir| Ok(Arc::new(list_images(dir))),
            usable,
            |sidecar| {
                read_bounded(sidecar)
                    .ok()
                    .flatten()
                    .map_or(Attempt::Next, usable)
            },
        )
    }))
    .unwrap_or(None)
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
