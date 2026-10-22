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
use rust_lib_kanaru::api::tags::{TrackCover, TrackTags};
use rust_lib_kanaru::cover_batch::read_covers;
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

/// A lossless WebP, 40×20, left half red and right half blue. `exif` is
/// stored as its EXIF chunk.
pub fn webp_halves(exif: Option<Vec<u8>>) -> Vec<u8> {
    use image::ImageEncoder;

    let pixels: Vec<u8> = (0..20)
        .flat_map(|_| (0..40).flat_map(|x| if x < 20 { [255, 0, 0] } else { [0, 0, 255] }))
        .collect();
    let mut out = Vec::new();
    let mut encoder = image::codecs::webp::WebPEncoder::new_lossless(&mut out);
    if let Some(exif) = exif {
        encoder.set_exif_metadata(exif).unwrap();
    }
    encoder
        .write_image(&pixels, 40, 20, image::ExtendedColorType::Rgb8)
        .unwrap();
    out
}

/// Big-endian TIFF block whose only entry is the EXIF orientation.
pub fn exif_tiff(orientation: u16) -> Vec<u8> {
    let mut tiff = b"MM\0\x2a\0\0\0\x08\0\x01\x01\x12\0\x03\0\0\0\x01".to_vec();
    tiff.extend_from_slice(&orientation.to_be_bytes());
    tiff.extend_from_slice(&[0; 6]);
    tiff
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

/// The covers of `paths`, written through `sink`.
pub fn read_all(paths: &[&Path], sink: &CoverSink) -> Vec<TrackCover> {
    read_covers(
        paths
            .iter()
            .map(|p| p.to_string_lossy().into_owned())
            .collect(),
        sink,
    )
}

pub fn read_with(path: &Path, sink: &CoverSink) -> TrackCover {
    read_all(&[path], sink).remove(0)
}

pub fn read_tags(path: &Path) -> TrackTags {
    read_batch(vec![path.to_string_lossy().into_owned()]).remove(0)
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

/// Makes the MIME length of the first PICTURE block absurd, so the block can
/// no longer be parsed.
pub fn corrupt_flac_picture_mime_length(path: &Path) {
    let mut bytes = fs::read(path).unwrap();
    assert_eq!(&bytes[..4], b"fLaC");
    let mut at = 4;
    loop {
        let header = bytes[at];
        let length = u32::from_be_bytes([0, bytes[at + 1], bytes[at + 2], bytes[at + 3]]) as usize;
        if header & 0x7F == 6 {
            // PICTURE body: picture type (4), then the MIME length (4).
            bytes[at + 8..at + 12].copy_from_slice(&0x00FF_FFF0u32.to_be_bytes());
            break;
        }
        assert_eq!(header & 0x80, 0, "no PICTURE block");
        at += 4 + length;
    }
    fs::write(path, bytes).unwrap();
}

pub fn mkfifo(path: &Path) {
    use std::ffi::CString;
    use std::os::unix::ffi::OsStrExt;

    let c_path = CString::new(path.as_os_str().as_bytes()).unwrap();
    // SAFETY: c_path is a valid NUL-terminated string that outlives the call.
    let rc = unsafe { libc::mkfifo(c_path.as_ptr(), 0o600) };
    assert_eq!(rc, 0, "mkfifo failed");
}
