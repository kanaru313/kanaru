//! Cover color API exposed to Dart.

use std::path::Path;

use rayon::prelude::*;

use crate::cover_batch::in_cover_pool;
use crate::cover_colors::colors_of_key;

/// Whether the colors of a thumbnail could be worked out.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum CoverColorStatus {
    /// The key is malformed, the thumbnail is missing, too large or not a
    /// JPEG that decodes, or the color code crashed.
    #[default]
    Failed,
    /// [`CoverColorResult::seed`] and [`CoverColorResult::palette`] are set.
    Done,
}

/// The colors of one cover thumbnail, from [`extract_cover_colors`].
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct CoverColorResult {
    /// The key as given.
    pub key: String,
    pub status: CoverColorStatus,
    /// Opaque ARGB seed for a color scheme; `0` when the cover has no color
    /// fit to tint the app (gray). `0` when failed.
    pub seed: u32,
    /// Opaque ARGB colors, the most common first, one to five. Empty when
    /// failed.
    pub palette: Vec<u32>,
}

/// The colors of each thumbnail in `keys` (`<ab>/<hash>.jpg`, relative to
/// `cover_dir`, the thumbnail folder with its size, e.g. `.../covers/512`).
/// Exactly one entry per key, in the same order; a key that fails never
/// fails the batch. Nothing is written.
///
/// `background` runs the batch on the low-priority cover threads (the scan);
/// otherwise it runs on the calling thread, so a cover for the track that
/// just started never waits behind a scan's thumbnails. When `cover_dir` is
/// empty every key fails.
pub fn extract_cover_colors(
    cover_dir: String,
    keys: Vec<String>,
    background: bool,
) -> Vec<CoverColorResult> {
    if cover_dir.is_empty() {
        return keys
            .into_iter()
            .map(|key| CoverColorResult {
                key,
                ..CoverColorResult::default()
            })
            .collect();
    }
    let dir = Path::new(&cover_dir);
    if background {
        in_cover_pool(|| {
            keys.into_par_iter()
                .map(|key| colors_of_key(dir, key))
                .collect()
        })
    } else {
        keys.into_iter()
            .map(|key| colors_of_key(dir, key))
            .collect()
    }
}
