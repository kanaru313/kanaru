//! A PNG or lossless WebP with alpha, 4096² (the largest the full decode
//! takes), is blended and resized on the decoded buffer: the peak stays near
//! the decode itself instead of adding a second buffer. Alone in its test
//! binary: it reads the process's peak memory, which other tests running
//! alongside would disturb. Both formats run one after the other; the big
//! buffers are mapped and unmapped per decode, so each starts from the same
//! resident size.

use std::io::Cursor;

use image::{DynamicImage, ImageBuffer, ImageFormat, Rgba};
use rust_lib_kanaru::cover_thumbnail::make_jpeg;

/// Peak resident memory of this process, in bytes.
fn peak_rss() -> u64 {
    let status = std::fs::read_to_string("/proc/self/status").unwrap();
    let line = status.lines().find(|l| l.starts_with("VmHWM:")).unwrap();
    let kib: u64 = line.split_whitespace().nth(1).unwrap().parse().unwrap();
    kib * 1024
}

fn rgba_4096(format: ImageFormat) -> Vec<u8> {
    let image = DynamicImage::ImageRgba8(ImageBuffer::from_fn(4096, 4096, |x, y| {
        Rgba([
            (x ^ y) as u8,
            (x * 3 + y) as u8,
            (y * 5) as u8,
            ((x + y) / 16) as u8,
        ])
    }));
    let mut out = Cursor::new(Vec::new());
    image.write_to(&mut out, format).unwrap();
    out.into_inner()
}

/// How much the process's peak grew while making the thumbnail of `bytes`.
fn peak_growth(bytes: &[u8], format: ImageFormat) -> u64 {
    // Reset the peak to what is resident now.
    std::fs::write("/proc/self/clear_refs", "5").unwrap();
    let before = peak_rss();
    let thumbnail = make_jpeg(bytes, format);
    let grew = peak_rss() - before;
    let size = image::load_from_memory(&thumbnail.unwrap())
        .unwrap()
        .into_rgb8()
        .dimensions();
    assert_eq!(size, (512, 512));
    grew
}

#[cfg(target_os = "linux")]
#[test]
fn rgba_4096_squares_stay_near_the_decoded_size() {
    // The decoded RGBA buffer is 64 MiB; blending into a second RGB buffer
    // used to put the peak at 112 MiB.
    let limit = 80 << 20;
    let png = rgba_4096(ImageFormat::Png);
    let grew = peak_growth(&png, ImageFormat::Png);
    assert!(grew < limit, "png: peak grew by {} MiB", grew >> 20);
    drop(png);
    let webp = rgba_4096(ImageFormat::WebP);
    let grew = peak_growth(&webp, ImageFormat::WebP);
    assert!(grew < limit, "webp: peak grew by {} MiB", grew >> 20);
}
