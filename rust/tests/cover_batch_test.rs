//! The covers-only batch: same choice and keys as the tag scan, and errors
//! that may pass reported as `Failed`, never as "no cover".

mod common;

use std::fs;
use std::path::Path;
use std::sync::mpsc;
use std::time::Duration;

use common::*;
use rust_lib_kanaru::api::tags::{read_covers_batch, read_tags_batch, CoverStatus, TrackCover};
use rust_lib_kanaru::cover_batch::read_covers;
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

fn strings(paths: &[&Path]) -> Vec<String> {
    paths
        .iter()
        .map(|p| p.to_string_lossy().into_owned())
        .collect()
}

fn covers(paths: &[&Path], cache: &Path) -> Vec<TrackCover> {
    let paths = strings(paths);
    let cache = cache.to_string_lossy().into_owned();
    within_seconds(20, move || read_covers_batch(paths, cache))
}

fn cover(path: &Path, cache: &Path) -> TrackCover {
    covers(&[path], cache).remove(0)
}

#[test]
fn keys_and_order_match_the_tag_scan() {
    let music = tempfile::tempdir().unwrap();
    let album = music.path().join("album");
    fs::create_dir(&album).unwrap();
    let embedded = with_cover("sample.flac", music.path(), "a.flac", &png(40, 40, 1));
    let shared = with_cover("sample.mp3", music.path(), "b.mp3", &jpeg(30, 30, 2));
    let folder = plain("sample.ogg", &album, "c.ogg");
    fs::write(album.join("Folder.JPG"), jpeg(20, 20, 3)).unwrap();
    let bare = plain("sample.opus", music.path(), "d.opus");
    let paths = [embedded.as_path(), &shared, &folder, &bare];

    let tag_cache = tempfile::tempdir().unwrap();
    let expected = read_tags_batch(
        strings(&paths),
        tag_cache.path().to_string_lossy().into_owned(),
    );
    let cache = tempfile::tempdir().unwrap();
    let got = covers(&paths, cache.path());

    assert_eq!(
        got.iter().map(|c| c.path.clone()).collect::<Vec<_>>(),
        strings(&paths)
    );
    for (cover, tags) in got.iter().zip(&expected) {
        assert_eq!(
            (&cover.cover, cover.status),
            (&tags.cover, tags.cover_status),
            "{}",
            cover.path
        );
    }
    assert_eq!(got[3].status, CoverStatus::None);
    assert_eq!(files_under(cache.path()), files_under(tag_cache.path()));
}

#[test]
fn empty_cover_folder_skips_every_file() {
    let music = tempfile::tempdir().unwrap();
    let path = with_cover("sample.flac", music.path(), "a.flac", &png(20, 20, 1));
    let result = read_covers_batch(
        strings(&[&path, &music.path().join("gone.mp3")]),
        String::new(),
    );
    assert_eq!(result.len(), 2);
    assert!(result
        .iter()
        .all(|c| c.status == CoverStatus::Skipped && c.cover.is_none()));
}

#[test]
fn missing_file_fails_and_is_not_none() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    // A folder cover is there, but the file is gone (unmounted, moved).
    fs::write(music.path().join("cover.jpg"), jpeg(20, 20, 1)).unwrap();
    let result = cover(&music.path().join("gone.mp3"), cache.path());
    assert_eq!((result.cover, result.status), (None, CoverStatus::Failed));
}

#[test]
fn fifo_named_like_audio_fails_fast() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let fifo = music.path().join("x.mp3");
    mkfifo(&fifo);
    let result = cover(&fifo, cache.path());
    assert_eq!(result.status, CoverStatus::Failed);
}

#[test]
fn corrupt_embedded_picture_falls_back_to_a_sidecar() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let path = with_cover("sample.flac", music.path(), "song.flac", &png(20, 20, 1));
    corrupt_flac_picture_mime_length(&path);
    let folder = jpeg(24, 24, 5);
    fs::write(music.path().join("cover.jpg"), &folder).unwrap();
    let result = cover(&path, cache.path());
    assert_eq!(result.cover, Some(cache_key(&folder)));
    assert_eq!(result.status, CoverStatus::Found);
}

#[test]
fn truncated_file_fails_and_is_not_none() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let path = with_cover("sample.flac", music.path(), "song.flac", &png(20, 20, 1));
    // Cut inside the PICTURE block: looks like a file still being copied.
    let bytes = fs::read(&path).unwrap();
    fs::write(&path, &bytes[..bytes.len() / 2]).unwrap();
    let result = cover(&path, cache.path());
    assert_eq!((result.cover, result.status), (None, CoverStatus::Failed));
}

#[test]
fn folder_that_cannot_be_listed_fails_and_is_not_none() {
    use std::os::unix::fs::PermissionsExt;

    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let path = plain("sample.flac", music.path(), "song.flac");
    fs::write(music.path().join("cover.jpg"), jpeg(20, 20, 1)).unwrap();
    // Files can still be opened by name, but the folder cannot be listed.
    fs::set_permissions(music.path(), fs::Permissions::from_mode(0o311)).unwrap();
    let listable = fs::read_dir(music.path()).is_ok();
    let result = cover(&path, cache.path());
    fs::set_permissions(music.path(), fs::Permissions::from_mode(0o755)).unwrap();
    if listable {
        return; // running as root: permissions do not apply
    }
    assert_eq!((result.cover, result.status), (None, CoverStatus::Failed));
}

#[test]
fn panic_for_one_file_fails_only_that_file() {
    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let a = with_cover("sample.flac", music.path(), "a.flac", &png(20, 20, 1));
    let b = with_cover("sample.flac", music.path(), "b.flac", &png(20, 20, 2));
    let sink = CoverSink::new(cache.path()).panicking_for_tests_on("a.flac");
    let result = read_covers(strings(&[&a, &b]), &sink);
    assert_eq!(result[0].status, CoverStatus::Failed);
    assert_eq!(result[1].status, CoverStatus::Found);
}

#[test]
fn read_only_cache_fails_the_cover() {
    use std::os::unix::fs::PermissionsExt;

    let music = tempfile::tempdir().unwrap();
    let cache = tempfile::tempdir().unwrap();
    let path = with_cover("sample.flac", music.path(), "song.flac", &png(20, 20, 1));
    fs::set_permissions(cache.path(), fs::Permissions::from_mode(0o555)).unwrap();
    let result = cover(&path, cache.path());
    fs::set_permissions(cache.path(), fs::Permissions::from_mode(0o755)).unwrap();
    assert_eq!((result.cover, result.status), (None, CoverStatus::Failed));
}
