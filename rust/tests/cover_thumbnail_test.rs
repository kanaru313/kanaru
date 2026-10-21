//! Shortcuts in making a thumbnail: they must give the same picture as the
//! full path, and never let bytes through that did not decode.

mod common;

use std::fs;
use std::path::Path;
use std::sync::mpsc;
use std::time::Duration;

use common::*;
use image::{GenericImageView, ImageFormat};
use rust_lib_kanaru::api::tags::{read_original_cover, CoverStatus};
use rust_lib_kanaru::cover_cache::{cache_key, CoverSink};
use rust_lib_kanaru::cover_thumbnail::make_jpeg;
use rust_lib_kanaru::jpeg_header::{ends_with_first_scan, parse, strip_metadata};

/// `jpeg` with an EXIF segment (orientation `orientation`) and a comment
/// inserted after SOI.
fn with_exif(jpeg: &[u8], orientation: u16) -> Vec<u8> {
    let mut tiff = b"MM\0\x2a\0\0\0\x08".to_vec();
    tiff.extend_from_slice(&1u16.to_be_bytes()); // one entry
    tiff.extend_from_slice(&[0x01, 0x12, 0x00, 0x03, 0, 0, 0, 1]);
    tiff.extend_from_slice(&orientation.to_be_bytes());
    tiff.extend_from_slice(&[0, 0, 0, 0, 0, 0]);
    let mut exif = b"Exif\0\0".to_vec();
    exif.extend_from_slice(&tiff);
    let mut out = jpeg[..2].to_vec();
    out.extend_from_slice(&[0xFF, 0xE1]);
    out.extend_from_slice(&(exif.len() as u16 + 2).to_be_bytes());
    out.extend_from_slice(&exif);
    out.extend_from_slice(&[0xFF, 0xFE, 0x00, 0x06, b'h', b'i', b'!', b'!']);
    out.extend_from_slice(&jpeg[2..]);
    out
}

/// A `width`×`height` JPEG written by jpeg-encoder: `color` is RGB (or CMYK
/// for `ColorType::Cmyk`), the same for every pixel.
fn encoded(
    width: u16,
    height: u16,
    color_type: jpeg_encoder::ColorType,
    color: &[u8],
    progressive: bool,
) -> Vec<u8> {
    let pixels: Vec<u8> = color
        .iter()
        .copied()
        .cycle()
        .take(usize::from(width) * usize::from(height) * color.len())
        .collect();
    let mut out = Vec::new();
    let mut encoder = jpeg_encoder::Encoder::new(&mut out, 90);
    encoder.set_progressive(progressive);
    encoder.encode(&pixels, width, height, color_type).unwrap();
    out
}

fn assert_color_near(thumbnail: &[u8], expected: [u8; 3]) {
    let image = image::load_from_memory(thumbnail).unwrap().into_rgb8();
    let (w, h) = image.dimensions();
    let pixel = image.get_pixel(w / 2, h / 2).0;
    for (got, want) in pixel.iter().zip(expected) {
        assert!(got.abs_diff(want) <= 6, "{pixel:?} vs {expected:?}");
    }
}

#[test]
fn large_jpeg_is_decoded_scaled_with_the_same_size_and_colours() {
    use jpeg_encoder::ColorType::{Luma, Rgb};

    for progressive in [false, true] {
        let wide = encoded(2000, 1000, Rgb, &[200, 40, 90], progressive);
        let thumbnail = make_jpeg(&wide, ImageFormat::Jpeg).unwrap();
        let size = image::load_from_memory(&thumbnail).unwrap().dimensions();
        assert_eq!(size, (512, 256), "progressive {progressive}");
        assert_color_near(&thumbnail, [200, 40, 90]);
    }
    let gray = encoded(1300, 1300, Luma, &[120], false);
    let thumbnail = make_jpeg(&gray, ImageFormat::Jpeg).unwrap();
    assert_eq!(
        image::load_from_memory(&thumbnail).unwrap().dimensions(),
        (512, 512)
    );
    assert_color_near(&thumbnail, [120, 120, 120]);
}

#[test]
fn large_cmyk_jpeg_takes_the_full_path() {
    let cmyk = encoded(
        1500,
        1500,
        jpeg_encoder::ColorType::Cmyk,
        &[0, 0, 0, 0],
        false,
    );
    assert_eq!(parse(&cmyk).unwrap().sampling.len(), 4);
    if let Some(thumbnail) = make_jpeg(&cmyk, ImageFormat::Jpeg) {
        let size = image::load_from_memory(&thumbnail).unwrap().dimensions();
        assert_eq!(size, (512, 512));
    }
}

#[test]
fn copies_of_one_large_cover_in_one_batch_finish() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let cover = encoded(2400, 2400, jpeg_encoder::ColorType::Rgb, &[1, 2, 3], true);
    let paths: Vec<_> = (0..8)
        .map(|i| with_cover("sample.flac", music.path(), &format!("{i}.flac"), &cover))
        .collect();
    let cache_dir = cache.path().to_owned();
    let (tx, rx) = mpsc::channel();
    std::thread::spawn(move || {
        let refs: Vec<&Path> = paths.iter().map(|p| p.as_path()).collect();
        let _ = tx.send(read_all(&refs, &CoverSink::new(&cache_dir)));
    });
    let found = rx
        .recv_timeout(Duration::from_secs(30))
        .expect("must not hang");
    assert!(found.iter().all(|c| c.status == CoverStatus::Found));
    assert_eq!(files_under(cache.path()), vec![cache_key(&cover)]);
}

#[test]
fn small_upright_baseline_jpeg_is_its_own_thumbnail_without_metadata() {
    let original = with_exif(&jpeg(300, 200, 4), 1);
    assert_eq!(parse(&original).unwrap().orientation, 1);
    let thumbnail = make_jpeg(&original, ImageFormat::Jpeg).unwrap();
    assert_eq!(Some(thumbnail.clone()), strip_metadata(&original));
    assert!(thumbnail.len() < original.len());
    assert!(!thumbnail.windows(4).any(|w| w == b"Exif"));
    let decoded = image::load_from_memory(&thumbnail).unwrap();
    assert_eq!(decoded.dimensions(), (300, 200));
}

#[test]
fn rotated_or_large_jpeg_is_encoded_again() {
    let rotated = with_exif(&jpeg(300, 200, 4), 6);
    assert_eq!(parse(&rotated).unwrap().orientation, 6);
    let thumbnail = make_jpeg(&rotated, ImageFormat::Jpeg).unwrap();
    assert_eq!(
        image::load_from_memory(&thumbnail).unwrap().dimensions(),
        (200, 300)
    );
    assert_ne!(Some(thumbnail), strip_metadata(&rotated));

    let large = jpeg(600, 300, 4);
    let thumbnail = make_jpeg(&large, ImageFormat::Jpeg).unwrap();
    let decoded = image::load_from_memory(&thumbnail).unwrap();
    assert_eq!(decoded.dimensions(), (512, 256));
}

#[test]
fn small_jpeg_that_does_not_decode_falls_back_to_the_folder_cover() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let good = jpeg(100, 100, 1);
    // Every header but no scan: nothing to decode.
    let sos = good.windows(2).position(|w| w == [0xFF, 0xDA]).unwrap();
    let broken = good[..sos].to_vec();
    assert_eq!(make_jpeg(&broken, ImageFormat::Jpeg), None);

    let path = with_cover("sample.flac", music.path(), "song.flac", &broken);
    let folder = jpeg(64, 64, 9);
    fs::write(music.path().join("cover.jpg"), &folder).unwrap();
    let found = read_with(&path, &CoverSink::new(cache.path()));
    assert_eq!(found.cover, Some(cache_key(&folder)));
}

#[test]
fn small_jpeg_cut_inside_its_scan_is_never_passed_through() {
    let good = jpeg(100, 100, 1);
    let sos = good.windows(2).position(|w| w == [0xFF, 0xDA]).unwrap();
    let cut = good[..sos + 20].to_vec();
    assert!(parse(&cut).is_some());
    // The decoder fills the missing data, so a thumbnail may come out, but
    // it is a complete image encoded here, not the cut original.
    if let Some(thumbnail) = make_jpeg(&cut, ImageFormat::Jpeg) {
        assert_ne!(Some(thumbnail.clone()), strip_metadata(&cut));
        assert!(thumbnail.ends_with(&[0xFF, 0xD9]));
    }
}

/// A uniform `side`×`side` progressive JPEG with full-resolution colour
/// (4:4:4), so its coefficients take as much memory as they can.
fn progressive_444(side: u16) -> Vec<u8> {
    let pixels = vec![120u8; usize::from(side) * usize::from(side) * 3];
    let mut out = Vec::new();
    let mut encoder = jpeg_encoder::Encoder::new(&mut out, 50);
    encoder.set_progressive(true);
    encoder.set_sampling_factor(jpeg_encoder::SamplingFactor::F_1_1);
    encoder
        .encode(&pixels, side, side, jpeg_encoder::ColorType::Rgb)
        .unwrap();
    out
}

#[test]
fn progressive_jpeg_under_the_decode_limit_is_thumbnailed() {
    // 1000² 4:4:4: about 6 MiB of coefficients, decoded in full.
    let thumbnail = make_jpeg(&progressive_444(1000), ImageFormat::Jpeg).unwrap();
    let decoded = image::load_from_memory(&thumbnail).unwrap();
    assert_eq!(decoded.dimensions(), (512, 512));
}

#[test]
fn progressive_jpeg_over_the_decode_limit_falls_back_to_the_folder_cover() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    // 4096² 4:4:4: 96 MiB of coefficients, over the limit at any scale.
    let huge = progressive_444(4096);
    assert_eq!(make_jpeg(&huge, ImageFormat::Jpeg), None);

    let path = with_cover("sample.flac", music.path(), "song.flac", &huge);
    let folder = jpeg(64, 64, 9);
    fs::write(music.path().join("cover.jpg"), &folder).unwrap();
    let found = read_with(&path, &CoverSink::new(cache.path()));
    assert_eq!(found.cover, Some(cache_key(&folder)));
    assert_eq!(found.status, CoverStatus::Found);
}

#[test]
fn original_cover_skips_an_embedded_jpeg_the_scan_cannot_decode() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let huge = progressive_444(4096);
    let path = with_cover("sample.flac", music.path(), "song.flac", &huge);
    let folder = jpeg(64, 64, 9);
    fs::write(music.path().join("cover.jpg"), &folder).unwrap();

    // The scan and the original pick the same cover.
    let found = read_with(&path, &CoverSink::new(cache.path()));
    assert_eq!(found.cover, Some(cache_key(&folder)));
    let original = read_original_cover(path.to_string_lossy().into_owned());
    assert_eq!(original, Some(folder));
}

#[test]
fn original_cover_keeps_a_large_progressive_jpeg_the_scan_decodes_scaled() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    // 3000² 4:4:4: 51.5 MiB of coefficients; fits at 1/4 scale, not in full.
    let embedded = progressive_444(3000);
    assert!(make_jpeg(&embedded, ImageFormat::Jpeg).is_some());
    let path = with_cover("sample.flac", music.path(), "song.flac", &embedded);
    fs::write(music.path().join("cover.jpg"), jpeg(64, 64, 9)).unwrap();

    let found = read_with(&path, &CoverSink::new(cache.path()));
    assert_eq!(found.cover, Some(cache_key(&embedded)));
    let original = read_original_cover(path.to_string_lossy().into_owned());
    assert_eq!(original, Some(embedded));
}

#[test]
fn small_jpeg_with_data_after_its_image_is_never_passed_through() {
    let good = jpeg(100, 100, 1);
    let mut padded = good.clone();
    padded.extend(std::iter::repeat_n(0xAB, 4000));
    padded.extend_from_slice(b"TRAILING-DATA");
    padded.extend_from_slice(&[0xFF, 0xD9]);
    // The decoder stops at the first EOI and never sees the rest.
    let thumbnail = make_jpeg(&padded, ImageFormat::Jpeg).unwrap();
    assert_ne!(Some(thumbnail.clone()), strip_metadata(&padded));
    assert!(!thumbnail.windows(13).any(|w| w == b"TRAILING-DATA"));
    assert_eq!(
        image::load_from_memory(&thumbnail).unwrap().dimensions(),
        (100, 100)
    );

    // The same image without the extra data is still its own thumbnail.
    let thumbnail = make_jpeg(&good, ImageFormat::Jpeg).unwrap();
    assert_eq!(Some(thumbnail), strip_metadata(&good));
}

#[test]
fn hostile_headers_never_panic_the_walk() {
    let seeds = [
        with_exif(&jpeg(40, 30, 1), 1),
        with_exif(&jpeg(600, 20, 2), 8),
        jpeg(8, 8, 3),
    ];
    // xorshift: deterministic, so a failure can be replayed.
    let mut state = 0x9E37_79B9_7F4A_7C15u64;
    let mut next = move || {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        state
    };
    for seed in &seeds {
        let header_len = seed.windows(2).position(|w| w == [0xFF, 0xDA]).unwrap() + 4;
        for _ in 0..2000 {
            let mut bytes = seed.clone();
            for _ in 0..1 + next() % 4 {
                let at = (next() as usize) % header_len;
                bytes[at] = next() as u8;
            }
            if next() % 4 == 0 {
                bytes.truncate((next() as usize) % bytes.len());
            }
            let _ = parse(&bytes);
            let _ = strip_metadata(&bytes);
            let _ = ends_with_first_scan(&bytes);
        }
    }
}

const RED: [u8; 3] = [230, 20, 20];
const BLUE: [u8; 3] = [20, 20, 230];

/// A `width`×`height` 4:4:4 JPEG, `RED` in the left half and `BLUE` in the
/// right half.
fn red_and_blue(width: u16, height: u16) -> Vec<u8> {
    let mut pixels = Vec::new();
    for _ in 0..height {
        for x in 0..width {
            pixels.extend_from_slice(if x < width / 2 { &RED } else { &BLUE });
        }
    }
    let mut out = Vec::new();
    let mut encoder = jpeg_encoder::Encoder::new(&mut out, 95);
    encoder.set_sampling_factor(jpeg_encoder::SamplingFactor::F_1_1);
    encoder
        .encode(&pixels, width, height, jpeg_encoder::ColorType::Rgb)
        .unwrap();
    out
}

fn assert_pixel_near(image: &image::RgbImage, (x, y): (u32, u32), expected: [u8; 3]) {
    let pixel = image.get_pixel(x, y).0;
    for (got, want) in pixel.iter().zip(expected) {
        assert!(
            got.abs_diff(want) <= 40,
            "({x}, {y}) is {pixel:?}, want {expected:?}"
        );
    }
}

fn thumbnail_of(jpeg: &[u8]) -> image::RgbImage {
    let thumbnail = make_jpeg(jpeg, ImageFormat::Jpeg).unwrap();
    image::load_from_memory(&thumbnail).unwrap().into_rgb8()
}

#[test]
fn rotated_jpeg_is_turned_upright() {
    let original = red_and_blue(300, 200);

    // 6: turned 90 degrees clockwise, the left half ends up on top.
    let image = thumbnail_of(&with_exif(&original, 6));
    assert_eq!(image.dimensions(), (200, 300));
    assert_pixel_near(&image, (100, 75), RED);
    assert_pixel_near(&image, (100, 225), BLUE);

    // 8: turned 90 degrees counter-clockwise, the left half ends up below.
    let image = thumbnail_of(&with_exif(&original, 8));
    assert_eq!(image.dimensions(), (200, 300));
    assert_pixel_near(&image, (100, 75), BLUE);
    assert_pixel_near(&image, (100, 225), RED);

    // 3: upside down, the left half ends up on the right.
    let image = thumbnail_of(&with_exif(&original, 3));
    assert_eq!(image.dimensions(), (300, 200));
    assert_pixel_near(&image, (75, 100), BLUE);
    assert_pixel_near(&image, (225, 100), RED);

    // 1 and values that are not an orientation: left as decoded.
    for orientation in [1, 0, 9, 0x0106] {
        let image = thumbnail_of(&with_exif(&original, orientation));
        assert_eq!(image.dimensions(), (300, 200), "orientation {orientation}");
        assert_pixel_near(&image, (75, 100), RED);
    }
}

#[test]
fn large_rotated_jpeg_decoded_scaled_is_turned_upright() {
    let original = red_and_blue(2048, 1024);
    let header = parse(&original).unwrap();
    assert_eq!((header.width, header.sampling.len()), (2048, 3));

    // Decoded at 1/4 (512×256), then turned: 256×512.
    let image = thumbnail_of(&with_exif(&original, 6));
    assert_eq!(image.dimensions(), (256, 512));
    assert_pixel_near(&image, (128, 128), RED);
    assert_pixel_near(&image, (128, 384), BLUE);
}

#[test]
fn thumbnail_size_does_not_depend_on_the_filter() {
    for ((width, height), expected) in [
        ((1001, 333), (512, 170)),
        ((4096, 1), (512, 1)),
        ((333, 1001), (170, 512)),
    ] {
        let thumbnail = make_jpeg(&png(width, height, 9), ImageFormat::Png).unwrap();
        let size = image::load_from_memory(&thumbnail).unwrap().dimensions();
        assert_eq!(size, expected, "{width}x{height}");
    }
}
