//! The colors of a cover, taken from its thumbnail in the cover cache: a seed
//! color for the app theme and a small palette for backgrounds.
//!
//! The thumbnail is not trusted: the file may be damaged, stale or written by
//! another tool, and a small original JPEG is stored as is. So it is read with
//! a byte cap, its header must declare at most [`THUMBNAIL_SIDE`] per side, and
//! it is decoded with the same limits as any cover.

use std::io::Cursor;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::Path;

use image::{imageops, ImageFormat, ImageReader};
use material_colors::color::{Argb, Lab};
use material_colors::hct::Hct;
use material_colors::quantize::{Quantizer, QuantizerMap, QuantizerResult, QuantizerWu};
use material_colors::score::Score;

use crate::api::cover_colors::{CoverColorResult, CoverColorStatus};
use crate::cover_art::read_capped;
use crate::cover_decode_limits::decode_limits;
use crate::cover_thumbnail::THUMBNAIL_SIDE;
use crate::jpeg_header;

/// Bumped whenever the colors this module returns for the same thumbnail
/// change. The Dart side stores it in `cover_colors.algo_version` (as
/// `coverColorAlgoRevision`, which must change with it), so stored colors
/// from an older revision are worked out again.
pub const COLOR_ALGO_REVISION: u32 = 1;

/// A seed whose HCT chroma is below this is too gray to tint the app: the
/// cover counts as having no accent color (seed `0`).
pub const MIN_SEED_CHROMA: f64 = 8.0;

/// The thumbnail is shrunk to at most this many pixels per side before the
/// colors are counted, as Flutter's `ColorScheme.fromImageProvider` does;
/// more pixels only cost time.
pub const MAX_SAMPLE_SIDE: u32 = 112;

/// Clusters the seed is picked from (as in Flutter and Android).
pub const SEED_CLUSTERS: usize = 128;

/// Colors in the palette, at most.
pub const PALETTE_SIZE: usize = 5;

/// A thumbnail file larger than this is not read. Real thumbnails are well
/// under 200 KiB.
pub const MAX_THUMBNAIL_BYTES: u64 = 1024 * 1024;

/// The colors of one image.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CoverColors {
    /// Opaque ARGB seed for a color scheme, or `0` when the image has no
    /// color fit to tint the app (gray, black and white, sepia-like).
    pub seed: u32,
    /// Opaque ARGB colors, the most common first; one to [`PALETTE_SIZE`].
    pub palette: Vec<u32>,
}

/// Whether `key` has the shape of a cover cache key, `<ab>/<hash>.jpg` with a
/// 64-character lowercase hex hash starting with the shard `ab`. Anything
/// else could point outside the cover folder.
pub fn is_cover_key(key: &str) -> bool {
    let Some((shard, file)) = key.split_once('/') else {
        return false;
    };
    let Some(hash) = file.strip_suffix(".jpg") else {
        return false;
    };
    let lower_hex = |s: &str| s.bytes().all(|b| matches!(b, b'0'..=b'9' | b'a'..=b'f'));
    shard.len() == 2 && hash.len() == 64 && lower_hex(hash) && hash.starts_with(shard)
}

/// The colors of the thumbnail `key` in `cover_dir`. Never panics; any
/// trouble gives [`CoverColorStatus::Failed`].
pub fn colors_of_key(cover_dir: &Path, key: String) -> CoverColorResult {
    let colors = if is_cover_key(&key) {
        read_capped(&cover_dir.join(&key), MAX_THUMBNAIL_BYTES)
            .ok()
            .flatten()
            .and_then(|bytes| {
                catch_unwind(AssertUnwindSafe(|| colors_of_thumbnail(&bytes))).unwrap_or(None)
            })
    } else {
        None
    };
    match colors {
        Some(CoverColors { seed, palette }) => CoverColorResult {
            key,
            status: CoverColorStatus::Done,
            seed,
            palette,
        },
        None => CoverColorResult {
            key,
            ..CoverColorResult::default()
        },
    }
}

/// The colors of a thumbnail JPEG. `None` when it is not a JPEG, declares a
/// side over [`THUMBNAIL_SIDE`] (or zero), or does not decode within the
/// cover decode limits.
pub fn colors_of_thumbnail(bytes: &[u8]) -> Option<CoverColors> {
    if !bytes.starts_with(&[0xFF, 0xD8, 0xFF]) {
        return None;
    }
    let header = jpeg_header::parse(bytes)?;
    let (width, height) = (u32::from(header.width), u32::from(header.height));
    if width == 0 || height == 0 || width.max(height) > THUMBNAIL_SIDE {
        return None;
    }
    let mut reader = ImageReader::with_format(Cursor::new(bytes), ImageFormat::Jpeg);
    reader.limits(decode_limits());
    let rgb = reader.decode().ok()?.into_rgb8();
    let longest = rgb.width().max(rgb.height());
    let sample = if longest > MAX_SAMPLE_SIDE {
        let fit = |side: u32| (side * MAX_SAMPLE_SIDE / longest).max(1);
        imageops::thumbnail(&rgb, fit(rgb.width()), fit(rgb.height()))
    } else {
        rgb
    };
    let pixels: Vec<Argb> = sample
        .pixels()
        .map(|p| Argb::new(255, p[0], p[1], p[2]))
        .collect();
    colors_of_pixels(&pixels)
}

/// The colors of opaque `pixels`. `None` when there are none.
///
/// Clusters come from the Wu quantizer, and each distinct pixel color is
/// counted toward its nearest cluster (CIE Lab distance). That is one pass
/// of the k-means refinement Flutter's `QuantizerCelebi` runs to
/// convergence, which in this crate costs about 25 times more for the same
/// image; one pass gives the populations `Score` needs.
pub fn colors_of_pixels(pixels: &[Argb]) -> Option<CoverColors> {
    if pixels.is_empty() {
        return None;
    }
    let distinct = QuantizerMap::quantize(pixels, 0).color_to_count;
    let distinct: Vec<(Argb, Lab, u32)> = distinct
        .into_iter()
        .map(|(color, count)| (color, Lab::from(color), count))
        .collect();
    let seed = seed_of(&clustered(pixels, &distinct, SEED_CLUSTERS));
    let mut clusters: Vec<(Argb, u32)> = clustered(pixels, &distinct, PALETTE_SIZE)
        .color_to_count
        .into_iter()
        .filter(|&(_, count)| count > 0)
        .collect();
    // Most common first; ties in a fixed order so the result is stable.
    clusters.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(&b.0)));
    let palette: Vec<u32> = clusters
        .into_iter()
        .take(PALETTE_SIZE)
        .map(|(color, _)| opaque(color))
        .collect();
    (!palette.is_empty()).then_some(CoverColors { seed, palette })
}

/// Up to `clusters` Wu clusters of `pixels`, each with the number of pixels
/// (from `distinct`: color, its Lab value, its count) nearest to it.
fn clustered(pixels: &[Argb], distinct: &[(Argb, Lab, u32)], clusters: usize) -> QuantizerResult {
    let mut result = QuantizerWu::quantize(pixels, clusters);
    let centers: Vec<(Argb, Lab)> = result
        .color_to_count
        .keys()
        .map(|&color| (color, Lab::from(color)))
        .collect();
    if centers.is_empty() {
        return result;
    }
    for &(_, lab, count) in distinct {
        let nearest = centers
            .iter()
            .map(|(color, center)| (color, lab_distance(&lab, center)))
            .min_by(|a, b| a.1.total_cmp(&b.1))
            .map(|(color, _)| *color);
        if let Some(color) = nearest {
            if let Some(population) = result.color_to_count.get_mut(&color) {
                *population += count;
            }
        }
    }
    result
}

fn lab_distance(a: &Lab, b: &Lab) -> f64 {
    let (dl, da, db) = (a.l - b.l, a.a - b.a, a.b - b.b);
    dl * dl + da * da + db * db
}

/// The theme seed of a quantized image, as Flutter's
/// `ColorScheme.fromImageProvider` picks it (`Score` with one color wanted
/// and filtering on), or `0` when no cluster fits or the pick is grayish
/// (chroma below [`MIN_SEED_CHROMA`]).
///
/// `Score` must never see an empty map or one whose counts add up to zero:
/// its sort then compares NaN scores with `unwrap_unchecked`, which is
/// undefined behaviour that `catch_unwind` cannot catch.
pub fn seed_of(quantized: &QuantizerResult) -> u32 {
    let counts = &quantized.color_to_count;
    if counts.is_empty() || counts.values().all(|&count| count == 0) {
        return 0;
    }
    let none = Argb::new(0, 0, 0, 0);
    let best = Score::score(counts, Some(1), Some(none), Some(true))
        .first()
        .copied()
        .unwrap_or(none);
    let hct: Hct = best.into();
    if best.alpha == 0 || hct.get_chroma() < MIN_SEED_CHROMA {
        return 0;
    }
    opaque(best)
}

fn opaque(color: Argb) -> u32 {
    0xFF00_0000 | u32::from(color.red) << 16 | u32::from(color.green) << 8 | u32::from(color.blue)
}
