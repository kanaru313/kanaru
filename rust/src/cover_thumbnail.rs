//! Turns an original cover image into the small JPEG the library shows.

use std::io::Cursor;
use std::panic::{catch_unwind, AssertUnwindSafe};

use image::metadata::Orientation;
use image::{DynamicImage, GrayImage, ImageFormat, ImageReader, RgbImage};

use crate::cover_decode_limits::{decode_limits, full_decode_fits, scaled_plan, ScaledPlan};
use crate::jpeg_header::{self, JpegHeader};
use crate::webp_exif;

/// Longest side of a thumbnail, in pixels. The cache folder is named after it
/// (`covers/512` on the Dart side), so a new size never mixes with old files.
pub const THUMBNAIL_SIDE: u32 = 512;

/// Upper bound on the buffers one decode may allocate (the pixel buffer, and
/// for a progressive JPEG its coefficients, see `cover_decode_limits`). It does
/// not cover what comes after the decode: flattening, `into_rgb8`, the resize
/// and the turn each allocate a buffer of about the size of their output. So a
/// cover thread may hold up to twice this limit, plus every picture lofty read
/// from the file it is working on (each at most `MAX_COVER_BYTES`). Each
/// thread runs one decode at a time, so the total grows with the thread count
/// chosen in `tag_batch`.
pub const MAX_DECODE_BYTES: u64 = 64 * 1024 * 1024;

const JPEG_QUALITY: u8 = 85;

/// Largest original JPEG used as its own thumbnail.
const MAX_PASSTHROUGH_BYTES: usize = 200 * 1024;

/// Decodes `bytes` (already checked by
/// [`validate_header`](crate::cover_art::validate_header)) and encodes a JPEG
/// whose longest side is [`THUMBNAIL_SIDE`], keeping the aspect ratio. Smaller
/// images are re-encoded at their own size, never enlarged. Transparent parts
/// end up on black. A JPEG or WebP is turned upright per its EXIF orientation. A
/// small upright baseline JPEG is its own thumbnail, minus its metadata (see
/// [`passthrough`]); a large JPEG is decoded scaled down (see
/// [`scaled_decode`]). Every shortcut falls back to the full path on any
/// trouble. `None` when the image breaks a decode limit or is corrupt.
pub fn make_jpeg(bytes: &[u8], format: ImageFormat) -> Option<Vec<u8>> {
    let image = match guarded(|| scaled_decode(bytes, format)) {
        Some(image) => image,
        None => {
            if !full_decode_fits(bytes, format) {
                return None;
            }
            let image = full_decode(bytes, format)?;
            if format == ImageFormat::Jpeg {
                if let Some(original) = guarded(|| passthrough(bytes, &image)) {
                    return Some(original);
                }
            }
            image
        }
    };

    // Flattened first: blending over black, then averaging, is what a
    // resize with premultiplied alpha followed by the blend would give.
    let rgb = shrink(flatten_on_black(image));
    // After the shrink: turning a thumbnail costs next to nothing and needs
    // no buffer the size of the original.
    encode(&turn_upright(rgb, exif_orientation(bytes, format)))
}

/// EXIF orientation of the original: from the JPEG header or the WebP `EXIF`
/// chunk; PNG is not read, so it counts as upright.
fn exif_orientation(bytes: &[u8], format: ImageFormat) -> u16 {
    match format {
        ImageFormat::Jpeg => jpeg_header::parse(bytes).map_or(1, |header| header.orientation),
        ImageFormat::WebP => webp_exif::orientation(bytes),
        _ => 1,
    }
}

/// `rgb` turned or flipped as the EXIF `orientation` says; a value that is
/// not an orientation leaves it as is. Neither the JPEG decoder nor `image`
/// applies it on its own.
fn turn_upright(rgb: RgbImage, orientation: u16) -> RgbImage {
    let orientation = u8::try_from(orientation)
        .ok()
        .and_then(Orientation::from_exif)
        .unwrap_or(Orientation::NoTransforms);
    if orientation == Orientation::NoTransforms {
        return rgb;
    }
    let mut image = DynamicImage::ImageRgb8(rgb);
    image.apply_orientation(orientation);
    image.into_rgb8()
}

/// `rgb` as a JPEG at [`JPEG_QUALITY`], colour at full resolution (4:4:4,
/// like the `image` encoder used before), so text and edges in covers keep
/// their colour.
fn encode(rgb: &RgbImage) -> Option<Vec<u8>> {
    let width = u16::try_from(rgb.width()).ok()?;
    let height = u16::try_from(rgb.height()).ok()?;
    let mut out = Vec::new();
    let mut encoder = jpeg_encoder::Encoder::new(&mut out, JPEG_QUALITY);
    encoder.set_sampling_factor(jpeg_encoder::SamplingFactor::F_1_1);
    encoder
        .encode(rgb.as_raw(), width, height, jpeg_encoder::ColorType::Rgb)
        .ok()?;
    Some(out)
}

/// Runs a shortcut; a panic inside it counts as "not taken".
fn guarded<T>(shortcut: impl FnOnce() -> Option<T>) -> Option<T> {
    catch_unwind(AssertUnwindSafe(shortcut)).ok().flatten()
}

fn full_decode(bytes: &[u8], format: ImageFormat) -> Option<DynamicImage> {
    let mut reader = ImageReader::with_format(Cursor::new(bytes), format);
    reader.limits(decode_limits());
    reader.decode().ok()
}

/// A large JPEG decoded at a DCT scale of 1/2, 1/4 or 1/8 (see
/// [`scaled_plan`] for when that applies). `None` when it does not apply or
/// on any error.
fn scaled_decode(bytes: &[u8], format: ImageFormat) -> Option<DynamicImage> {
    let ScaledPlan {
        mut decoder,
        width,
        height,
        output,
    } = scaled_plan(bytes, format)?;
    decoder.set_max_decoding_buffer_size(output as usize);
    let pixels = decoder.decode().ok()?;
    let (width, height) = (u32::from(width), u32::from(height));
    match decoder.info()?.pixel_format {
        jpeg_decoder::PixelFormat::RGB24 => {
            RgbImage::from_raw(width, height, pixels).map(DynamicImage::ImageRgb8)
        }
        jpeg_decoder::PixelFormat::L8 => {
            GrayImage::from_raw(width, height, pixels).map(DynamicImage::ImageLuma8)
        }
        _ => None,
    }
}

/// The original JPEG without its metadata segments, when it can serve as
/// its own thumbnail: at most [`THUMBNAIL_SIDE`] and [`MAX_PASSTHROUGH_BYTES`],
/// one scan that runs into the final EOI, baseline, three YCbCr components,
/// upright (EXIF orientation 1, since the EXIF segment goes), one frame
/// whose size matches `decoded`. `decoded` is the full decode of `bytes`, so
/// only bytes that decode reach the cache; the decoder fills a scan that was
/// cut short without complaint and stops at the first EOI, hence the scan
/// check.
fn passthrough(bytes: &[u8], decoded: &DynamicImage) -> Option<Vec<u8>> {
    if bytes.len() > MAX_PASSTHROUGH_BYTES || !jpeg_header::ends_with_first_scan(bytes) {
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

/// `rgb` fitted within [`THUMBNAIL_SIDE`] (aspect kept, rounded like
/// `image`'s `thumbnail`), or as is when it already fits. Resized with
/// fast_image_resize (Lanczos3, SIMD chosen at run time); on any error, with
/// `image`.
fn shrink(rgb: RgbImage) -> RgbImage {
    let (width, height) = rgb.dimensions();
    let longest = width.max(height);
    if longest <= THUMBNAIL_SIDE {
        return rgb;
    }
    let ratio = f64::from(THUMBNAIL_SIDE) / f64::from(longest);
    let fit = |side: u32| ((f64::from(side) * ratio).round() as u32).max(1);
    let (new_width, new_height) = (fit(width), fit(height));
    guarded(|| {
        use fast_image_resize as fir;
        let source =
            fir::images::ImageRef::new(width, height, rgb.as_raw(), fir::PixelType::U8x3).ok()?;
        let mut target = fir::images::Image::new(new_width, new_height, fir::PixelType::U8x3);
        let options = fir::ResizeOptions::new()
            .resize_alg(fir::ResizeAlg::Convolution(fir::FilterType::Lanczos3));
        fir::Resizer::new()
            .resize(&source, &mut target, &options)
            .ok()?;
        RgbImage::from_raw(new_width, new_height, target.into_vec())
    })
    .unwrap_or_else(|| image::imageops::thumbnail(&rgb, new_width, new_height))
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

    #[test]
    fn shrink_rings_at_edges() {
        // A step edge in the middle: a convolution with negative lobes
        // (Lanczos) overshoots on both sides, a bilinear blend never does.
        let step = RgbImage::from_fn(1024, 8, |x, _| {
            let level = if x < 512 { 64 } else { 192 };
            image::Rgb([level; 3])
        });
        let shrunk = shrink(step);
        assert_eq!(shrunk.dimensions(), (512, 4));
        assert!(shrunk.pixels().any(|p| p.0[0] < 64 || p.0[0] > 192));
    }
}
