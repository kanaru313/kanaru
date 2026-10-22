//! The cover cache under failure, hostile sidecar files, broken embedded
//! pictures, and reading the original cover on demand.

mod common;

use std::fs;
use std::path::Path;
use std::sync::mpsc;
use std::time::Duration;

use common::*;
use image::GenericImageView;
use lofty::config::WriteOptions;
use lofty::file::TaggedFileExt;
use lofty::picture::{MimeType, Picture, PictureType};
use lofty::prelude::*;
use rust_lib_kanaru::api::tags::{read_covers_batch, read_original_cover, CoverStatus, TrackCover};
use rust_lib_kanaru::cover_cache::{cache_key, CoverSink};

/// Runs `work` on a thread so a hang fails the test instead of the suite.
fn within_seconds<T: Send + 'static>(seconds: u64, work: impl FnOnce() -> T + Send + 'static) -> T {
    let (tx, rx) = mpsc::channel();
    std::thread::spawn(move || {
        let _ = tx.send(work());
    });
    rx.recv_timeout(Duration::from_secs(seconds))
        .expect("must not hang")
}

fn read_in_thread(path: &Path, cache: &Path) -> TrackCover {
    let path = path.to_string_lossy().into_owned();
    let cache = cache.to_string_lossy().into_owned();
    within_seconds(20, move || read_covers_batch(vec![path], cache).remove(0))
}

#[test]
fn batch_api_writes_into_the_given_folder() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let cover = png(64, 64, 9);
    let path = with_cover("sample.flac", music.path(), "song.flac", &cover);
    let found = read_in_thread(&path, cache.path());
    assert_eq!(found.cover, Some(cache_key(&cover)));
    assert_eq!(files_under(cache.path()), vec![cache_key(&cover)]);
}

#[test]
fn read_only_cache_fails_the_cover() {
    use std::os::unix::fs::PermissionsExt;

    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    fs::set_permissions(cache.path(), fs::Permissions::from_mode(0o555)).unwrap();
    let path = with_cover("sample.flac", music.path(), "song.flac", &png(20, 20, 1));
    let found = read_with(&path, &CoverSink::new(cache.path()));
    fs::set_permissions(cache.path(), fs::Permissions::from_mode(0o755)).unwrap();
    assert_eq!((found.cover, found.status), (None, CoverStatus::Failed));
}

#[test]
fn panic_in_the_cover_code_fails_the_cover() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let path = with_cover("sample.flac", music.path(), "song.flac", &png(20, 20, 1));
    let sink = CoverSink::new(cache.path()).panicking_for_tests();
    let found = read_with(&path, &sink);
    assert_eq!((found.cover, found.status), (None, CoverStatus::Failed));
}

#[test]
fn empty_cached_thumbnail_is_written_again() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let cover = png(20, 20, 3);
    let key = cache_key(&cover);
    fs::create_dir_all(cache.path().join(&key[..2])).unwrap();
    fs::write(cache.path().join(&key), b"").unwrap();
    let path = with_cover("sample.flac", music.path(), "song.flac", &cover);
    let sink = CoverSink::new(cache.path());
    assert_eq!(read_with(&path, &sink).cover, Some(key.clone()));
    assert_eq!(sink.thumbnails_made(), 1);
    assert!(image::load_from_memory(&fs::read(cache.path().join(&key)).unwrap()).is_ok());
}

#[test]
fn successful_batch_leaves_no_temp_files() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let paths: Vec<_> = (0..12)
        .map(|i| {
            with_cover(
                "sample.flac",
                music.path(),
                &format!("{i}.flac"),
                &png(30, 30, i),
            )
        })
        .collect();
    let refs: Vec<&Path> = paths.iter().map(|p| p.as_path()).collect();
    let results = read_all(&refs, &CoverSink::new(cache.path()));
    assert!(results.iter().all(|c| c.status == CoverStatus::Found));
    let files = files_under(cache.path());
    assert_eq!(files.len(), 12);
    assert!(
        files.iter().all(|f| !f.contains(".kanaru-tmp")),
        "{files:?}"
    );
}

#[test]
fn hostile_sidecar_files_neither_hang_nor_fill_memory() {
    use std::os::unix::fs::symlink;

    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let path = plain("sample.flac", music.path(), "song.flac");
    mkfifo(&music.path().join("folder.jpg"));
    fs::create_dir(music.path().join("front.png")).unwrap();
    let found = read_in_thread(&path, cache.path());
    assert_eq!((found.cover, found.status), (None, CoverStatus::None));

    // A "regular" file whose reads fail: not proof that there is no cover.
    symlink("/proc/self/pagemap", music.path().join("cover.jpg")).unwrap();
    let found = read_in_thread(&path, cache.path());
    assert_eq!((found.cover, found.status), (None, CoverStatus::Failed));
}

#[test]
fn sidecar_over_the_size_limit_is_skipped() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let path = plain("sample.flac", music.path(), "song.flac");
    let mut huge = jpeg(8, 8, 1);
    huge.resize(17 * 1024 * 1024, 0);
    fs::write(music.path().join("cover.jpg"), &huge).unwrap();
    let folder = jpeg(8, 8, 2);
    fs::write(music.path().join("folder.jpg"), &folder).unwrap();
    let found = read_with(&path, &CoverSink::new(cache.path()));
    assert_eq!(found.cover, Some(cache_key(&folder)));
    assert_eq!(
        read_original_cover(path.to_string_lossy().into_owned()),
        Some(folder)
    );
}

#[test]
fn corrupt_flac_picture_counts_as_no_embedded_cover() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let path = with_cover("sample.flac", music.path(), "song.flac", &png(20, 20, 1));
    corrupt_flac_picture_mime_length(&path);
    let found = read_with(&path, &CoverSink::new(cache.path()));
    assert_eq!((found.cover, found.status), (None, CoverStatus::None));
    let tags = read_tags(&path);
    assert_eq!(tags.error, None);
    assert_eq!(tags.title.as_deref(), Some("Test_Title"));
}

#[test]
fn oversized_mp4_cover_gives_no_cover() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let path = music.path().join("song.m4a");
    fs::copy(fixture("sample.m4a"), &path).unwrap();
    let mut tagged = lofty::read_from_path(&path).unwrap();
    let mut huge = jpeg(8, 8, 1);
    huge.resize(17 * 1024 * 1024, 0);
    let picture = Picture::unchecked(huge)
        .pic_type(PictureType::Other)
        .mime_type(MimeType::Jpeg)
        .build();
    tagged.primary_tag_mut().unwrap().push_picture(picture);
    tagged.save_to_path(&path, WriteOptions::default()).unwrap();

    // lofty rejects an MP4 atom over its 16 MiB allocation limit: a
    // permanent error, so the file counts as having no embedded cover.
    let found = read_with(&path, &CoverSink::new(cache.path()));
    assert_eq!((found.cover, found.status), (None, CoverStatus::None));
}

#[test]
fn original_cover_follows_the_scan_order_and_writes_nothing() {
    let music = tempfile::tempdir().unwrap();
    let embedded = png(40, 40, 1);
    let with_embedded = with_cover("sample.mp3", music.path(), "a.mp3", &embedded);
    let own = jpeg(40, 40, 2);
    let with_stem = plain("sample.flac", music.path(), "b.flac");
    fs::write(music.path().join("b.jpg"), &own).unwrap();
    let folder = png(40, 40, 3);
    fs::write(music.path().join("folder.png"), &folder).unwrap();
    let with_folder = plain("sample.ogg", music.path(), "c.ogg");
    let before = files_under(music.path());

    let original = |p: &Path| read_original_cover(p.to_string_lossy().into_owned());
    assert_eq!(original(&with_embedded), Some(embedded));
    assert_eq!(original(&with_stem), Some(own));
    assert_eq!(original(&with_folder), Some(folder));
    assert_eq!(files_under(music.path()), before);

    let bare = tempfile::tempdir().unwrap();
    assert_eq!(original(&plain("sample.opus", bare.path(), "d.opus")), None);
    assert_eq!(original(&bare.path().join("missing.flac")), None);
}

#[test]
fn sidecar_holding_a_webp_with_exif_is_turned_upright() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let path = plain("sample.flac", music.path(), "song.flac");
    // The extension says JPEG; the content decides.
    fs::write(
        music.path().join("cover.jpg"),
        webp_halves(Some(exif_tiff(6))),
    )
    .unwrap();
    let found = read_with(&path, &CoverSink::new(cache.path()));
    let key = found.cover.expect("the sidecar is the cover");
    let thumbnail = fs::read(cache.path().join(&key)).unwrap();
    assert_eq!(
        image::load_from_memory(&thumbnail).unwrap().dimensions(),
        (20, 40)
    );
}
