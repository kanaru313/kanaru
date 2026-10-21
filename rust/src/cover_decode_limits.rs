//! What a decode of a cover may take, checked from the headers alone. The
//! thumbnail maker and the original-cover reader share these rules, so the
//! reader only offers images the scan can turn into a thumbnail.

use std::io::Cursor;
use std::panic::{catch_unwind, AssertUnwindSafe};

use image::{ImageDecoder, ImageFormat, ImageReader, Limits};

use crate::cover_art::MAX_COVER_SIDE;
use crate::cover_thumbnail::{MAX_DECODE_BYTES, THUMBNAIL_SIDE};
use crate::jpeg_header::{self, JpegHeader};

/// JPEGs with a longer side are decoded at 1/2, 1/4 or 1/8 of their size,
/// still at least [`THUMBNAIL_SIDE`]: most of the decode work is skipped.
const SCALED_DECODE_ABOVE: u32 = 1024;

/// The limits of a full decode.
pub(crate) fn decode_limits() -> Limits {
    let mut limits = Limits::default();
    limits.max_image_width = Some(MAX_COVER_SIDE);
    limits.max_image_height = Some(MAX_COVER_SIDE);
    limits.max_alloc = Some(MAX_DECODE_BYTES);
    limits
}

/// A scaled JPEG decode that is allowed: the decoder, set to the smallest DCT
/// scale (1/2, 1/4, 1/8) that keeps the longest side at least
/// [`THUMBNAIL_SIDE`], and the size it will produce.
pub(crate) struct ScaledPlan<'a> {
    pub decoder: jpeg_decoder::Decoder<Cursor<&'a [u8]>>,
    pub width: u16,
    pub height: u16,
    /// Bytes of the decoded pixels.
    pub output: u64,
}

/// The scaled decode of `bytes`, when it applies: a JPEG whose longest side
/// is over [`SCALED_DECODE_ABOVE`] and within [`MAX_COVER_SIDE`], gray or
/// YCbCr (or RGB; CMYK and YCCK take the full path), whose decode needs no
/// more than [`MAX_DECODE_BYTES`] (see [`progressive_coefficient_bytes`]).
/// Only headers are read.
pub(crate) fn scaled_plan(bytes: &[u8], format: ImageFormat) -> Option<ScaledPlan<'_>> {
    if format != ImageFormat::Jpeg {
        return None;
    }
    let header = jpeg_header::parse(bytes)?;
    let side = u32::from(header.width.max(header.height));
    if side <= SCALED_DECODE_ABOVE || side > MAX_COVER_SIDE || header.sampling.len() == 4 {
        return None;
    }
    let mut decoder = jpeg_decoder::Decoder::new(Cursor::new(bytes));
    let side = THUMBNAIL_SIDE as u16;
    let (width, height) = decoder.scale(side, side).ok()?;
    let output = u64::from(width) * u64::from(height) * header.sampling.len() as u64;
    // The output is held about twice: component planes, then the
    // interleaved pixels.
    if progressive_coefficient_bytes(&header) + 2 * output > MAX_DECODE_BYTES {
        return None;
    }
    Some(ScaledPlan {
        decoder,
        width,
        height,
        output,
    })
}

/// Whether the full decode of `bytes` keeps to [`MAX_DECODE_BYTES`].
/// `image`'s limit only bounds the output buffer, but a progressive JPEG
/// also keeps every coefficient of the image until its last scan (see
/// [`progressive_coefficient_bytes`]), so one that would need more is
/// refused: no thumbnail, rather than a decode far over the limit. Other
/// images are left to `image`'s own limits.
pub(crate) fn full_decode_fits(bytes: &[u8], format: ImageFormat) -> bool {
    if format != ImageFormat::Jpeg {
        return true;
    }
    let Some(header) = jpeg_header::parse(bytes) else {
        return true;
    };
    if !header.progressive {
        return true;
    }
    let output = u64::from(header.width) * u64::from(header.height) * header.sampling.len() as u64;
    progressive_coefficient_bytes(&header) + output <= MAX_DECODE_BYTES
}

/// Whether `image` would let a full decode of `bytes` allocate its output
/// within [`decode_limits`]: what `ImageReader::decode` checks after reading
/// the header (size, then the output buffer against the allocation left).
fn full_output_fits(bytes: &[u8], format: ImageFormat) -> bool {
    let mut reader = ImageReader::with_format(Cursor::new(bytes), format);
    reader.limits(decode_limits());
    let Ok(decoder) = reader.into_decoder() else {
        return false;
    };
    decode_limits().reserve(decoder.total_bytes()).is_ok()
}

/// Whether [`make_jpeg`](crate::cover_thumbnail::make_jpeg) accepts `bytes`
/// as far as decode limits go, found from the headers without decoding a
/// pixel. A damaged body can still fail the decode later; a header that
/// makes the checks panic counts as not fitting.
pub(crate) fn decode_fits(bytes: &[u8], format: ImageFormat) -> bool {
    catch_unwind(AssertUnwindSafe(|| {
        scaled_plan(bytes, format).is_some()
            || (full_decode_fits(bytes, format) && full_output_fits(bytes, format))
    }))
    .unwrap_or(false)
}

/// What a decode holds besides its output, at most: a progressive JPEG
/// keeps every DCT coefficient of the full-size image (64 two-byte values
/// per 8×8 block, blocks padded to whole MCUs) until its last scan, at any
/// output scale; a baseline one decodes row by row. The output comes on
/// top, counted by the caller.
fn progressive_coefficient_bytes(header: &JpegHeader) -> u64 {
    if !header.progressive {
        return 0;
    }
    let h_max = header
        .sampling
        .iter()
        .map(|s| u64::from(s.0))
        .max()
        .unwrap_or(1);
    let v_max = header
        .sampling
        .iter()
        .map(|s| u64::from(s.1))
        .max()
        .unwrap_or(1);
    let mcus_x = u64::from(header.width).div_ceil(8 * h_max);
    let mcus_y = u64::from(header.height).div_ceil(8 * v_max);
    let blocks: u64 = header
        .sampling
        .iter()
        .map(|&(h, v)| mcus_x * u64::from(h) * mcus_y * u64::from(v))
        .sum();
    blocks * 64 * 2
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cover_thumbnail::make_jpeg;

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
    fn progressive_decode_memory_counts_padded_blocks() {
        let progressive = |width, height, sampling: Vec<(u8, u8)>| JpegHeader {
            width,
            height,
            progressive: true,
            sampling,
            ..header()
        };
        assert_eq!(progressive_coefficient_bytes(&header()), 0, "baseline");
        // 2000×1000 4:2:0: 125×63 MCUs; 4 luma + 2 chroma blocks per MCU.
        let blocks = 125 * 63 * 6;
        let yuv420 = progressive(2000, 1000, vec![(2, 2), (1, 1), (1, 1)]);
        assert_eq!(progressive_coefficient_bytes(&yuv420), blocks * 128);
        // 4096² 4:4:4: 3 × 512² blocks = 96 MiB, over the cap.
        let full = progressive(4096, 4096, vec![(1, 1); 3]);
        assert_eq!(progressive_coefficient_bytes(&full), 3 * 512 * 512 * 128);
        assert!(progressive_coefficient_bytes(&full) > MAX_DECODE_BYTES);
    }

    /// A uniform `side`×`side` JPEG.
    fn jpeg(side: u16, color: jpeg_encoder::ColorType, progressive: bool) -> Vec<u8> {
        let channels = if color == jpeg_encoder::ColorType::Cmyk {
            4
        } else {
            3
        };
        let pixels = vec![120u8; usize::from(side) * usize::from(side) * channels];
        let mut out = Vec::new();
        let mut encoder = jpeg_encoder::Encoder::new(&mut out, 50);
        encoder.set_progressive(progressive);
        encoder.set_sampling_factor(jpeg_encoder::SamplingFactor::F_1_1);
        encoder.encode(&pixels, side, side, color).unwrap();
        out
    }

    fn png(width: u32, height: u32, rgba16: bool) -> Vec<u8> {
        let image = if rgba16 {
            image::DynamicImage::ImageRgba16(image::ImageBuffer::new(width, height))
        } else {
            image::DynamicImage::ImageRgb8(image::ImageBuffer::new(width, height))
        };
        let mut out = Cursor::new(Vec::new());
        image.write_to(&mut out, ImageFormat::Png).unwrap();
        out.into_inner()
    }

    #[test]
    fn decode_fits_agrees_with_make_jpeg() {
        use jpeg_encoder::ColorType::{Cmyk, Rgb};

        let samples = [
            ("baseline 100", jpeg(100, Rgb, false), ImageFormat::Jpeg),
            ("baseline 2048", jpeg(2048, Rgb, false), ImageFormat::Jpeg),
            ("progressive 1000", jpeg(1000, Rgb, true), ImageFormat::Jpeg),
            ("progressive 3000", jpeg(3000, Rgb, true), ImageFormat::Jpeg),
            ("progressive 4096", jpeg(4096, Rgb, true), ImageFormat::Jpeg),
            ("cmyk 2000", jpeg(2000, Cmyk, false), ImageFormat::Jpeg),
            ("png 64", png(64, 64, false), ImageFormat::Png),
            ("png rgba16 3000", png(3000, 3000, true), ImageFormat::Png),
        ];
        for (name, bytes, format) in samples {
            assert_eq!(
                decode_fits(&bytes, format),
                make_jpeg(&bytes, format).is_some(),
                "{name}"
            );
        }
    }

    #[test]
    fn decode_fits_never_panics_on_hostile_headers() {
        let bases = [
            (
                jpeg(1300, jpeg_encoder::ColorType::Rgb, true),
                ImageFormat::Jpeg,
            ),
            (png(64, 64, false), ImageFormat::Png),
        ];
        let mut state = 0x9E37_79B9_7F4A_7C15u64;
        let mut next = move || {
            state ^= state << 13;
            state ^= state >> 7;
            state ^= state << 17;
            state
        };
        for (base, format) in bases {
            for _ in 0..500 {
                let mut bytes = base.clone();
                let limit = bytes.len().min(400);
                for _ in 0..4 {
                    let at = (next() % limit as u64) as usize;
                    bytes[at] = next() as u8;
                }
                let cut = (next() % bytes.len() as u64) as usize;
                bytes.truncate(cut.max(2));
                let _ = decode_fits(&bytes, format);
            }
        }
    }
}
