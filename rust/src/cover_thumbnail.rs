//! Turns an original cover image into the small JPEG the library shows.

use std::io::Cursor;
use std::panic::{catch_unwind, AssertUnwindSafe};

use image::codecs::jpeg::JpegEncoder;
use image::{DynamicImage, ImageFormat, ImageReader, Limits, RgbImage};

use crate::cover_art::MAX_COVER_SIDE;
use crate::jpeg_header::{self, JpegHeader};

/// Longest side of a thumbnail, in pixels. The cache folder is named after it
/// (`covers/512` on the Dart side), so a new size never mixes with old files.
pub const THUMBNAIL_SIDE: u32 = 512;

/// Upper bound on what one decode may allocate. Each cover thread runs one
/// decode at a time, so total decode memory grows with the thread count
/// chosen in `tag_batch`.
pub const MAX_DECODE_BYTES: u64 = 64 * 1024 * 1024;

const JPEG_QUALITY: u8 = 85;

/// Largest original JPEG used as its own thumbnail.
const MAX_PASSTHROUGH_BYTES: usize = 200 * 1024;

/// Decodes `bytes` (already checked by
/// [`validate_header`](crate::cover_art::validate_header)) and encodes a JPEG
/// whose longest side is [`THUMBNAIL_SIDE`], keeping the aspect ratio. Smaller
/// images are re-encoded at their own size, never enlarged. Transparent parts
/// end up on black. A small upright baseline JPEG is its own thumbnail, minus
/// its metadata (see [`passthrough`]). `None` when the image breaks a decode
/// limit or is corrupt.
pub fn make_jpeg(bytes: &[u8], format: ImageFormat) -> Option<Vec<u8>> {
    let mut reader = ImageReader::with_format(Cursor::new(bytes), format);
    let mut limits = Limits::default();
    limits.max_image_width = Some(MAX_COVER_SIDE);
    limits.max_image_height = Some(MAX_COVER_SIDE);
    limits.max_alloc = Some(MAX_DECODE_BYTES);
    reader.limits(limits);
    let image = reader.decode().ok()?;
    if format == ImageFormat::Jpeg {
        // Any trouble on this shortcut falls back to re-encoding.
        if let Ok(Some(original)) = catch_unwind(AssertUnwindSafe(|| passthrough(bytes, &image))) {
            return Some(original);
        }
    }

    let image = if image.width().max(image.height()) > THUMBNAIL_SIDE {
        image.thumbnail(THUMBNAIL_SIDE, THUMBNAIL_SIDE)
    } else {
        image
    };
    let rgb = flatten_on_black(image);

    let mut out = Vec::new();
    JpegEncoder::new_with_quality(&mut out, JPEG_QUALITY)
        .encode_image(&rgb)
        .ok()?;
    Some(out)
}

/// The original JPEG without its metadata segments, when it can serve as
/// its own thumbnail: at most [`THUMBNAIL_SIDE`] and [`MAX_PASSTHROUGH_BYTES`],
/// complete (ends with EOI), baseline, three YCbCr components, upright (EXIF
/// orientation 1, since the EXIF segment goes), one frame whose size matches
/// `decoded`. `decoded` is the full decode of `bytes`, so only bytes that
/// decode reach the cache; the decoder fills a scan that was cut short
/// without complaint, hence the EOI check.
fn passthrough(bytes: &[u8], decoded: &DynamicImage) -> Option<Vec<u8>> {
    if bytes.len() > MAX_PASSTHROUGH_BYTES || !bytes.ends_with(&[0xFF, 0xD9]) {
        return None;
    }
    let header = jpeg_header::parse(bytes)?;
    if !fits_as_is(&header, (decoded.width(), decoded.height())) {
        return None;
    }
    jpeg_header::strip_metadata(bytes)
}

fn fits_as_is(header: &JpegHeader, decoded: (u32, u32)) -> bool {
    let size = (u32::from(header.width), u32::from(header.height));
    !header.progressive
        && header.sampling.len() == 3
        && header
            .adobe_transform
            .is_none_or(|transform| transform == 1)
        && header.orientation == 1
        && size.0.max(size.1) <= THUMBNAIL_SIDE
        && size == decoded
}

/// JPEG has no alpha channel: blends every pixel over black.
fn flatten_on_black(image: DynamicImage) -> RgbImage {
    if !image.color().has_alpha() {
        return image.into_rgb8();
    }
    let rgba = image.into_rgba8();
    RgbImage::from_fn(rgba.width(), rgba.height(), |x, y| {
        let [r, g, b, a] = rgba.get_pixel(x, y).0;
        let blend = |c: u8| ((u16::from(c) * u16::from(a) + 127) / 255) as u8;
        image::Rgb([blend(r), blend(g), blend(b)])
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn header() -> JpegHeader {
        JpegHeader {
            width: 400,
            height: 300,
            progressive: false,
            sampling: vec![(2, 2), (1, 1), (1, 1)],
            adobe_transform: None,
            orientation: 1,
        }
    }

    #[test]
    fn only_small_upright_baseline_ycbcr_fits_as_is() {
        assert!(fits_as_is(&header(), (400, 300)));
        assert!(fits_as_is(
            &JpegHeader {
                adobe_transform: Some(1),
                ..header()
            },
            (400, 300)
        ));
        let refused = [
            JpegHeader {
                progressive: true,
                ..header()
            },
            JpegHeader {
                sampling: vec![(1, 1); 4],
                ..header()
            },
            JpegHeader {
                sampling: vec![(1, 1)],
                ..header()
            },
            JpegHeader {
                adobe_transform: Some(2),
                ..header()
            },
            JpegHeader {
                adobe_transform: Some(0),
                ..header()
            },
            JpegHeader {
                orientation: 6,
                ..header()
            },
            JpegHeader {
                width: 513,
                ..header()
            },
        ];
        for refused in refused {
            let size = (u32::from(refused.width), u32::from(refused.height));
            assert!(!fits_as_is(&refused, size), "{refused:?}");
        }
        assert!(!fits_as_is(&header(), (300, 400)), "decoded size differs");
    }
}
