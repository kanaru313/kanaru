//! Shortcuts in making a thumbnail: they must give the same picture as the
//! full path, and never let bytes through that did not decode.

mod common;

use std::fs;
use std::path::Path;
use std::sync::mpsc;
use std::time::Duration;

use common::*;
use image::{GenericImageView, ImageFormat};
use rust_lib_kanaru::api::tags::CoverStatus;
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
