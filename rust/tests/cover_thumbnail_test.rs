//! Shortcuts in making a thumbnail: they must give the same picture as the
//! full path, and never let bytes through that did not decode.

mod common;

use std::fs;

use common::*;
use image::{GenericImageView, ImageFormat};
use rust_lib_kanaru::cover_cache::{cache_key, CoverSink};
use rust_lib_kanaru::cover_thumbnail::make_jpeg;
use rust_lib_kanaru::jpeg_header::{parse, strip_metadata};

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
        }
    }
}
