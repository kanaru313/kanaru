//! Reads lyrics written into copies of the tiny fixtures, plus the broken
//! and hostile inputs the reader must survive.

use std::borrow::Cow;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::mpsc;
use std::time::Duration;

use lofty::config::WriteOptions;
use lofty::file::TaggedFileExt;
use lofty::id3::v2::{
    BinaryFrame, ExtendedTextFrame, Frame, FrameId, Id3v2Tag, SyncTextContentType,
    SynchronizedTextFrame, TimestampFormat, UnsynchronizedTextFrame,
};
use lofty::tag::{ItemKey, Tag, TagExt};
use lofty::TextEncoding;
use tempfile::TempDir;

use rust_lib_kanaru::api::lyrics::{read_embedded_lyrics, EmbeddedLyrics, SyncedLyricLine};

fn fixture(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(name)
}

/// A writable copy of fixture `name` in `dir`.
fn copy(dir: &TempDir, name: &str) -> PathBuf {
    let target = dir.path().join(name);
    fs::copy(fixture(name), &target).expect("copy fixture");
    target
}

fn read(path: &Path) -> Option<EmbeddedLyrics> {
    read_embedded_lyrics(path.to_string_lossy().into_owned())
}

/// Writes `text` under `key` into the file's primary tag (created if
/// missing), through lofty's generic tag.
fn write_generic(path: &Path, key: ItemKey, text: &str) {
    let tagged = lofty::read_from_path(path).expect("read fixture");
    let mut tag = tagged
        .primary_tag()
        .cloned()
        .unwrap_or_else(|| Tag::new(tagged.primary_tag_type()));
    assert!(tag.insert_text(key, text.to_owned()), "{path:?}");
    tag.save_to_path(path, WriteOptions::default())
        .expect("save tag");
}

fn sylt(
    content_type: SyncTextContentType,
    format: TimestampFormat,
    lines: &[(u32, &str)],
) -> Frame<'static> {
    let frame = SynchronizedTextFrame::new(
        TextEncoding::UTF8,
        *b"eng",
        format,
        content_type,
        None,
        lines.iter().map(|(t, s)| (*t, (*s).to_owned())).collect(),
    );
    let bytes = frame
        .as_bytes(WriteOptions::default())
        .expect("encode SYLT");
    Frame::Binary(BinaryFrame::new(
        FrameId::Valid(Cow::Borrowed("SYLT")),
        bytes,
    ))
}

fn uslt(text: &str) -> Frame<'static> {
    Frame::UnsynchronizedText(UnsynchronizedTextFrame::new(
        TextEncoding::UTF8,
        *b"eng",
        String::new(),
        text.to_owned(),
    ))
}

fn write_id3v2(path: &Path, frames: Vec<Frame<'static>>) {
    let mut tag = Id3v2Tag::new();
    for frame in frames {
        tag.insert(frame);
    }
    tag.save_to_path(path, WriteOptions::default())
        .expect("save ID3v2");
}

fn line(time_ms: u32, text: &str) -> SyncedLyricLine {
    SyncedLyricLine {
        time_ms,
        text: text.to_owned(),
    }
}

#[test]
fn reads_the_lyrics_field_of_every_tag_format() {
    let dir = TempDir::new().unwrap();
    for name in [
        "sample.flac",
        "sample.ogg",
        "sample.opus",
        "sample.m4a",
        "sample.ape",
        "sample.wv",
    ] {
        let path = copy(&dir, name);
        write_generic(&path, ItemKey::Lyrics, "[00:01.00]Hello\n[00:02.00]World");
        let lyrics = read(&path).unwrap_or_else(|| panic!("{name}: no lyrics"));
        assert_eq!(
            lyrics.text.as_deref(),
            Some("[00:01.00]Hello\n[00:02.00]World"),
            "{name}"
        );
        assert!(lyrics.synced.is_empty(), "{name}");
    }
}

#[test]
fn reads_vorbis_unsynced_lyrics() {
    let dir = TempDir::new().unwrap();
    let path = copy(&dir, "sample.flac");
    write_generic(&path, ItemKey::UnsyncLyrics, "Plain words");
    assert_eq!(read(&path).unwrap().text.as_deref(), Some("Plain words"));
}

#[test]
fn reads_id3v2_uslt_and_sylt_from_mp3_wav_and_aiff() {
    let dir = TempDir::new().unwrap();
    for name in ["sample.mp3", "sample.wav", "sample.aiff"] {
        let path = copy(&dir, name);
        write_id3v2(
            &path,
            vec![
                uslt("Plain words"),
                sylt(
                    SyncTextContentType::Lyrics,
                    TimestampFormat::MS,
                    &[(2500, "\nSecond"), (1000, "First")],
                ),
            ],
        );
        let lyrics = read(&path).unwrap_or_else(|| panic!("{name}: no lyrics"));
        assert_eq!(lyrics.text.as_deref(), Some("Plain words"), "{name}");
        assert_eq!(
            lyrics.synced,
            vec![line(1000, "First"), line(2500, "Second")],
            "{name}"
        );
    }
}

#[test]
fn reads_txxx_lyrics_when_no_uslt_exists() {
    let dir = TempDir::new().unwrap();
    let path = copy(&dir, "sample.mp3");
    write_id3v2(
        &path,
        vec![Frame::UserText(ExtendedTextFrame::new(
            TextEncoding::UTF8,
            "LYRICS",
            "From TXXX",
        ))],
    );
    assert_eq!(read(&path).unwrap().text.as_deref(), Some("From TXXX"));
}

#[test]
fn sylt_alone_is_enough() {
    let dir = TempDir::new().unwrap();
    let path = copy(&dir, "sample.mp3");
    write_id3v2(
        &path,
        vec![sylt(
            SyncTextContentType::Lyrics,
            TimestampFormat::MS,
            &[(0, "Only")],
        )],
    );
    let lyrics = read(&path).unwrap();
    assert_eq!(lyrics.text, None);
    assert_eq!(lyrics.synced, vec![line(0, "Only")]);
}

#[test]
fn sylt_in_mpeg_frames_or_of_another_type_is_skipped() {
    let dir = TempDir::new().unwrap();
    let path = copy(&dir, "sample.mp3");
    write_id3v2(
        &path,
        vec![
            sylt(
                SyncTextContentType::Lyrics,
                TimestampFormat::MPEG,
                &[(10, "frames")],
            ),
            sylt(
                SyncTextContentType::Chord,
                TimestampFormat::MS,
                &[(10, "Bb F")],
            ),
        ],
    );
    assert_eq!(read(&path), None);
}

#[test]
fn sylt_typed_other_is_used_when_no_lyrics_frame_exists() {
    let dir = TempDir::new().unwrap();
    let path = copy(&dir, "sample.mp3");
    write_id3v2(
        &path,
        vec![sylt(
            SyncTextContentType::Other,
            TimestampFormat::MS,
            &[(5, "other")],
        )],
    );
    assert_eq!(read(&path).unwrap().synced, vec![line(5, "other")]);
}

#[test]
fn files_without_lyrics_give_none() {
    for name in [
        "sample.mp3",
        "sample.flac",
        "sample.m4a",
        "sample.ogg",
        "sample.wav",
    ] {
        assert_eq!(read(&fixture(name)), None, "{name}");
    }
}

#[test]
fn blank_lyrics_count_as_none() {
    let dir = TempDir::new().unwrap();
    let path = copy(&dir, "sample.flac");
    write_generic(&path, ItemKey::Lyrics, "  \n ");
    assert_eq!(read(&path), None);
}

#[test]
fn oversized_text_is_dropped() {
    let dir = TempDir::new().unwrap();
    let path = copy(&dir, "sample.flac");
    write_generic(&path, ItemKey::Lyrics, &"a".repeat(1024 * 1024 + 1));
    assert_eq!(read(&path), None);
}

#[test]
fn missing_folders_and_garbage_give_none() {
    let dir = TempDir::new().unwrap();
    assert_eq!(read(&dir.path().join("missing.mp3")), None);
    assert_eq!(read(dir.path()), None);
    let garbage = dir.path().join("garbage.mp3");
    fs::write(&garbage, b"ID3\x04\x00\x00\x7f\x7f\x7f\x7fnot really a tag").unwrap();
    assert_eq!(read(&garbage), None);
    let empty = dir.path().join("empty.flac");
    fs::write(&empty, b"").unwrap();
    assert_eq!(read(&empty), None);
}

#[cfg(unix)]
#[test]
fn a_fifo_is_never_waited_on() {
    let dir = TempDir::new().unwrap();
    let fifo = dir.path().join("pipe.mp3");
    let c_path = std::ffi::CString::new(fifo.to_string_lossy().as_bytes()).unwrap();
    // SAFETY: a valid NUL-terminated path; mkfifo only creates the node.
    assert_eq!(unsafe { libc::mkfifo(c_path.as_ptr(), 0o600) }, 0);
    let (sender, receiver) = mpsc::channel();
    std::thread::spawn(move || sender.send(read(&fifo)).unwrap());
    let result = receiver
        .recv_timeout(Duration::from_secs(5))
        .expect("reading a FIFO must not block");
    assert_eq!(result, None);
}
