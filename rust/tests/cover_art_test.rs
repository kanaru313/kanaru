//! Which image becomes a file's cover, and what its thumbnail looks like.

mod common;

use std::fs;

use common::*;
use image::{DynamicImage, GenericImageView, ImageFormat, Rgba, RgbaImage};
use lofty::picture::PictureType;
use rust_lib_kanaru::api::tags::CoverStatus;
use rust_lib_kanaru::cover_art::validate_header;
use rust_lib_kanaru::cover_cache::{cache_key, CoverSink};
use rust_lib_kanaru::cover_thumbnail::make_jpeg;

fn thumbnail_size(cache: &std::path::Path, key: &str) -> (u32, u32) {
    let bytes = fs::read(cache.join(key)).unwrap();
    assert_eq!(validate_header(&bytes), Some(ImageFormat::Jpeg));
    image::load_from_memory(&bytes).unwrap().dimensions()
}

#[test]
fn header_check_accepts_jpeg_png_webp_only() {
    assert_eq!(validate_header(&jpeg(8, 8, 1)), Some(ImageFormat::Jpeg));
    assert_eq!(validate_header(&png(8, 8, 1)), Some(ImageFormat::Png));
    let webp = image_bytes(8, 8, ImageFormat::WebP, 1);
    assert_eq!(validate_header(&webp), Some(ImageFormat::WebP));

    assert_eq!(validate_header(b"GIF89a\x01\x00\x01\x00\x00\x00\x00"), None);
    assert_eq!(
        validate_header(b"BM\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"),
        None
    );
    assert_eq!(validate_header(b"-->http://example.com/cover.jpg"), None);
    assert_eq!(validate_header(&[0x5A; 64]), None);
    assert_eq!(validate_header(&[]), None);
}

#[test]
fn header_check_rejects_oversized_images_without_decoding() {
    assert_eq!(validate_header(&png_claiming(30_000, 30_000)), None);
    assert_eq!(validate_header(&png(4097, 1, 1)), None);
    assert_eq!(validate_header(&png(4096, 1, 1)), Some(ImageFormat::Png));
}

#[test]
fn thumbnail_keeps_aspect_ratio_and_never_enlarges() {
    let big = make_jpeg(&png(2000, 1000, 1), ImageFormat::Png).unwrap();
    assert_eq!(
        image::load_from_memory(&big).unwrap().dimensions(),
        (512, 256)
    );
    let tall = make_jpeg(&jpeg(600, 1200, 1), ImageFormat::Jpeg).unwrap();
    assert_eq!(
        image::load_from_memory(&tall).unwrap().dimensions(),
        (256, 512)
    );
    let small = make_jpeg(&png(300, 300, 1), ImageFormat::Png).unwrap();
    assert_eq!(validate_header(&small), Some(ImageFormat::Jpeg));
    assert_eq!(
        image::load_from_memory(&small).unwrap().dimensions(),
        (300, 300)
    );
}

#[test]
fn transparent_pixels_end_up_black() {
    let clear = RgbaImage::from_pixel(64, 64, Rgba([255, 255, 255, 0]));
    let bytes = encode(DynamicImage::ImageRgba8(clear), ImageFormat::Png);
    let thumb = image::load_from_memory(&make_jpeg(&bytes, ImageFormat::Png).unwrap())
        .unwrap()
        .into_rgb8();
    let [r, g, b] = thumb.get_pixel(32, 32).0;
    assert!(r < 8 && g < 8 && b < 8, "expected black, got {r},{g},{b}");
}

#[test]
fn decode_over_the_memory_limit_is_refused() {
    // 4000×4000 16-bit RGBA needs 128 MiB, over the 64 MiB decode limit.
    let bomb = png_claiming(4000, 4000);
    assert_eq!(validate_header(&bomb), Some(ImageFormat::Png));
    assert_eq!(make_jpeg(&bomb, ImageFormat::Png), None);
}

#[test]
fn embedded_cover_of_each_format_becomes_a_cached_thumbnail() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let sink = CoverSink::new(cache.path());
    for (index, name) in [
        "sample.mp3",
        "sample.flac",
        "sample.m4a",
        "sample.ogg",
        "sample.opus",
    ]
    .into_iter()
    .enumerate()
    {
        let cover = png(800, 600, index as u8);
        let path = with_cover(name, music.path(), name, &cover);
        let tags = read_with(&path, &sink);
        assert_eq!(tags.error, None, "{name}");
        assert_eq!(tags.title.as_deref(), Some("Test_Title"), "{name}");
        assert_eq!(tags.cover_status, CoverStatus::Found, "{name}");
        let key = tags.cover.expect(name);
        assert_eq!(key, cache_key(&cover), "{name}");
        assert_eq!(thumbnail_size(cache.path(), &key), (512, 384), "{name}");
    }
}

#[test]
fn front_cover_wins_over_earlier_pictures() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let sink = CoverSink::new(cache.path());
    let back = png(40, 40, 1);
    let front = png(40, 40, 2);
    for name in ["sample.mp3", "sample.flac"] {
        let pictures: [(&[u8], PictureType); 2] = [
            (&back, PictureType::CoverBack),
            (&front, PictureType::CoverFront),
        ];
        let path = with_pictures(name, music.path(), name, &pictures);
        assert_eq!(
            read_with(&path, &sink).cover,
            Some(cache_key(&front)),
            "{name}"
        );
    }
}

#[test]
fn files_sharing_a_cover_share_one_thumbnail_decoded_once() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let sink = CoverSink::new(cache.path());
    let cover = png(100, 100, 7);
    let a = with_cover("sample.flac", music.path(), "a.flac", &cover);
    let b = with_cover("sample.flac", music.path(), "b.flac", &cover);
    read_with(&a, &sink);
    let second = read_with(&b, &sink);
    assert_eq!(second.cover, Some(cache_key(&cover)));
    assert_eq!(sink.thumbnails_made(), 1);
    assert_eq!(files_under(cache.path()), vec![cache_key(&cover)]);
}

#[test]
fn embedded_cover_beats_a_cover_named_after_the_track() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let embedded = png(20, 20, 1);
    let path = with_cover("sample.flac", music.path(), "song.flac", &embedded);
    fs::write(music.path().join("song.jpg"), jpeg(20, 20, 2)).unwrap();
    let tags = read_with(&path, &CoverSink::new(cache.path()));
    assert_eq!(tags.cover, Some(cache_key(&embedded)));
}

#[test]
fn cover_named_after_the_track_beats_folder_covers() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let path = plain("sample.flac", music.path(), "Song.flac");
    let own = png(20, 20, 1);
    fs::write(music.path().join("Song.PNG"), &own).unwrap();
    fs::write(music.path().join("cover.jpg"), jpeg(20, 20, 2)).unwrap();
    let tags = read_with(&path, &CoverSink::new(cache.path()));
    assert_eq!(tags.cover, Some(cache_key(&own)));
    assert_eq!(tags.cover_status, CoverStatus::Found);
}

#[test]
fn folder_covers_go_cover_then_folder_then_front_in_any_case() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let sink = CoverSink::new(cache.path());
    let path = plain("sample.flac", music.path(), "song.flac");
    let cover = png(20, 20, 1);
    fs::write(music.path().join("cover.png"), &cover).unwrap();
    fs::write(music.path().join("folder.jpg"), jpeg(20, 20, 2)).unwrap();
    assert_eq!(read_with(&path, &sink).cover, Some(cache_key(&cover)));

    let other = tempfile::tempdir().unwrap();
    let path = plain("sample.flac", other.path(), "song.flac");
    let upper = jpeg(20, 20, 3);
    fs::write(other.path().join("Cover.JPG"), &upper).unwrap();
    fs::write(other.path().join("front.jpg"), jpeg(20, 20, 4)).unwrap();
    assert_eq!(read_with(&path, &sink).cover, Some(cache_key(&upper)));
}

#[test]
fn unusable_source_falls_through_to_the_next() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let path = with_cover("sample.mp3", music.path(), "song.mp3", &png(5000, 1, 1));
    fs::write(music.path().join("song.jpg"), b"not an image").unwrap();
    let folder = jpeg(30, 30, 2);
    fs::write(music.path().join("cover.jpg"), &folder).unwrap();
    let tags = read_with(&path, &CoverSink::new(cache.path()));
    assert_eq!(tags.cover, Some(cache_key(&folder)));
}

#[test]
fn unusable_images_give_no_cover_and_keep_the_tags() {
    let cache = tempfile::tempdir().unwrap();
    let sink = CoverSink::new(cache.path());
    let gif = b"GIF89a\x01\x00\x01\x00\x00\x00\x00".to_vec();
    for bad in [gif, png_claiming(30_000, 30_000), png_claiming(4000, 4000)] {
        let music = tempfile::tempdir().unwrap();
        let path = with_cover("sample.flac", music.path(), "song.flac", &bad);
        let tags = read_with(&path, &sink);
        assert_eq!(tags.cover, None);
        assert_eq!(tags.cover_status, CoverStatus::None);
        assert_eq!(tags_only(tags), tags_only(read_without_covers(&path)));
    }
    assert!(files_under(cache.path()).is_empty());
}

#[test]
fn unreadable_tags_still_get_a_folder_cover() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let path = music.path().join("track.dsf");
    fs::write(&path, b"DSD fake content").unwrap();
    let folder = jpeg(30, 30, 5);
    fs::write(music.path().join("folder.jpg"), &folder).unwrap();
    let tags = read_with(&path, &CoverSink::new(cache.path()));
    assert_eq!(tags.error.as_deref(), Some("unsupported"));
    assert_eq!(tags.cover, Some(cache_key(&folder)));
    assert_eq!(tags.cover_status, CoverStatus::Found);
}

#[test]
fn no_cover_anywhere_is_none() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let path = plain("sample.ogg", music.path(), "song.ogg");
    let tags = read_with(&path, &CoverSink::new(cache.path()));
    assert_eq!((tags.cover, tags.cover_status), (None, CoverStatus::None));
}

#[test]
fn covers_off_reads_exactly_the_old_tags() {
    let music = tempfile::tempdir().unwrap();
    let path = with_cover("sample.mp3", music.path(), "song.mp3", &png(20, 20, 1));
    let tags = read_without_covers(&path);
    assert_eq!(tags.cover_status, CoverStatus::Skipped);
    assert_eq!(tags.cover, None);
    assert_eq!(tags.title.as_deref(), Some("Test_Title"));
}
