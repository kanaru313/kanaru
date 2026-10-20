//! Turns an original cover image into the small JPEG the library shows.

use std::io::Cursor;

use image::codecs::jpeg::JpegEncoder;
use image::{DynamicImage, ImageFormat, ImageReader, Limits, RgbImage};

use crate::cover_art::MAX_COVER_SIDE;

/// Longest side of a thumbnail, in pixels. The cache folder is named after it
/// (`covers/512` on the Dart side), so a new size never mixes with old files.
pub const THUMBNAIL_SIDE: u32 = 512;

/// Upper bound on what one decode may allocate. With at most four tag threads
/// this caps decode memory at about 256 MiB.
pub const MAX_DECODE_BYTES: u64 = 64 * 1024 * 1024;

const JPEG_QUALITY: u8 = 85;

/// Decodes `bytes` (already checked by
/// [`validate_header`](crate::cover_art::validate_header)) and encodes a JPEG
/// whose longest side is [`THUMBNAIL_SIDE`], keeping the aspect ratio. Smaller
/// images are re-encoded at their own size, never enlarged. Transparent parts
/// end up on black. `None` when the image breaks a decode limit or is corrupt.
pub fn make_jpeg(bytes: &[u8], format: ImageFormat) -> Option<Vec<u8>> {
    let mut reader = ImageReader::with_format(Cursor::new(bytes), format);
    let mut limits = Limits::default();
    limits.max_image_width = Some(MAX_COVER_SIDE);
    limits.max_image_height = Some(MAX_COVER_SIDE);
    limits.max_alloc = Some(MAX_DECODE_BYTES);
    reader.limits(limits);
    let image = reader.decode().ok()?;

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
