//! Helpers shared by the cover tests: images made in memory and audio
//! fixtures copied into a temp folder with pictures embedded.

#![allow(dead_code)]

use std::fs;
use std::io::Cursor;
use std::path::{Path, PathBuf};

use image::{DynamicImage, ImageFormat, Rgba, RgbaImage};
use lofty::config::WriteOptions;
use lofty::file::{AudioFile, TaggedFileExt};
use lofty::picture::{MimeType, Picture, PictureType};
use lofty::tag::Tag;
use rust_lib_kanaru::api::tags::{CoverStatus, TrackTags};
use rust_lib_kanaru::cover_cache::CoverSink;
use rust_lib_kanaru::tag_batch::read_batch;

pub fn fixture(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(name)
}

/// An opaque image of `width`×`height` encoded as `format`; `shade` makes
/// images with the same size differ.
pub fn image_bytes(width: u32, height: u32, format: ImageFormat, shade: u8) -> Vec<u8> {
    let image = RgbaImage::from_pixel(width, height, Rgba([shade, 100, 200, 255]));
    encode(DynamicImage::ImageRgba8(image), format)
}

pub fn encode(image: DynamicImage, format: ImageFormat) -> Vec<u8> {
    let image = if format == ImageFormat::Jpeg {
        DynamicImage::ImageRgb8(image.into_rgb8())
    } else {
        image
    };
    let mut out = Cursor::new(Vec::new());
    image.write_to(&mut out, format).unwrap();
    out.into_inner()
}

pub fn png(width: u32, height: u32, shade: u8) -> Vec<u8> {
    image_bytes(width, height, ImageFormat::Png, shade)
}

pub fn jpeg(width: u32, height: u32, shade: u8) -> Vec<u8> {
    image_bytes(width, height, ImageFormat::Jpeg, shade)
}

/// A 1×1 16-bit RGBA PNG whose header claims `width`×`height`, with a valid
/// header checksum. Decoding it would need `width × height × 8` bytes.
pub fn png_claiming(width: u32, height: u32) -> Vec<u8> {
    let image = DynamicImage::ImageRgba16(image::ImageBuffer::new(1, 1));
    let mut bytes = encode(image, ImageFormat::Png);
    // Signature (8) + chunk length (4) + "IHDR" (4), then width and height.
    bytes[16..20].copy_from_slice(&width.to_be_bytes());
    bytes[20..24].copy_from_slice(&height.to_be_bytes());
    let crc = crc32(&bytes[12..29]);
    bytes[29..33].copy_from_slice(&crc.to_be_bytes());
    bytes
}

fn crc32(data: &[u8]) -> u32 {
    let mut crc = 0xFFFF_FFFFu32;
    for byte in data {
        crc ^= u32::from(*byte);
        for _ in 0..8 {
            let mask = (crc & 1).wrapping_neg();
            crc = (crc >> 1) ^ (0xEDB8_8320 & mask);
        }
    }
    !crc
}

/// Copies `fixture_name` into `dir` as `file_name` and embeds `pictures`.
pub fn with_pictures(
    fixture_name: &str,
    dir: &Path,
    file_name: &str,
    pictures: &[(&[u8], PictureType)],
) -> PathBuf {
    let path = dir.join(file_name);
    fs::copy(fixture(fixture_name), &path).unwrap();
    let mut tagged = lofty::read_from_path(&path).unwrap();
    if tagged.primary_tag().is_none() {
        tagged.insert_tag(Tag::new(tagged.file_type().primary_tag_type()));
    }
    let tag = tagged.primary_tag_mut().unwrap();
    for (bytes, kind) in pictures {
        let picture = Picture::unchecked(bytes.to_vec())
            .pic_type(*kind)
            .mime_type(MimeType::Png)
            .build();
        tag.push_picture(picture);
    }
    tagged.save_to_path(&path, WriteOptions::default()).unwrap();
    path
}

/// Copies `fixture_name` into `dir` as `file_name` with one front cover.
pub fn with_cover(fixture_name: &str, dir: &Path, file_name: &str, bytes: &[u8]) -> PathBuf {
    with_pictures(
        fixture_name,
        dir,
        file_name,
        &[(bytes, PictureType::CoverFront)],
    )
}

/// Copies `fixture_name` into `dir` as `file_name`, unchanged.
pub fn plain(fixture_name: &str, dir: &Path, file_name: &str) -> PathBuf {
    let path = dir.join(file_name);
    fs::copy(fixture(fixture_name), &path).unwrap();
    path
}

pub fn read_all(paths: &[&Path], sink: &CoverSink) -> Vec<TrackTags> {
    read_batch(
        paths
            .iter()
            .map(|p| p.to_string_lossy().into_owned())
            .collect(),
        Some(sink),
    )
}

pub fn read_with(path: &Path, sink: &CoverSink) -> TrackTags {
    read_all(&[path], sink).remove(0)
}

pub fn read_without_covers(path: &Path) -> TrackTags {
    read_batch(vec![path.to_string_lossy().into_owned()], None).remove(0)
}

/// The tag part of `tags`, for comparing reads with and without covers.
pub fn tags_only(mut tags: TrackTags) -> TrackTags {
    tags.cover = None;
    tags.cover_status = CoverStatus::Skipped;
    tags
}

/// Every file under `dir`, relative, sorted.
pub fn files_under(dir: &Path) -> Vec<String> {
    let mut found = Vec::new();
    collect(dir, dir, &mut found);
    found.sort();
    found
}

fn collect(root: &Path, dir: &Path, found: &mut Vec<String>) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if entry.file_type().unwrap().is_dir() {
            collect(root, &path, found);
        } else {
            found.push(
                path.strip_prefix(root)
                    .unwrap()
                    .to_string_lossy()
                    .into_owned(),
            );
        }
    }
}
