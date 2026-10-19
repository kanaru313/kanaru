//! Reads real (tiny) files of every extension the indexer scans, plus the
//! broken and hostile inputs it must survive.

use std::fs;
use std::path::PathBuf;
use std::sync::mpsc;
use std::time::Duration;

use rust_lib_kanaru::api::tags::{read_tags_batch, TrackTags};

fn fixture(name: &str) -> String {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(name)
        .to_string_lossy()
        .into_owned()
}

fn read(path: &str) -> TrackTags {
    let mut result = read_tags_batch(vec![path.to_owned()]);
    assert_eq!(result.len(), 1);
    result.remove(0)
}

fn assert_readable(tags: &TrackTags) {
    assert_eq!(tags.error, None, "{}", tags.path);
    let duration = tags.duration_ms.expect("duration");
    assert!((400..=700).contains(&duration), "duration {duration}");
    assert_eq!(tags.sample_rate, Some(8000), "{}", tags.path);
    assert_eq!(tags.channels, Some(1), "{}", tags.path);
}

/// Formats whose tag container carries the full field set.
const FULLY_TAGGED: [&str; 8] = [
    "sample.mp3",
    "sample.flac",
    "sample.m4a",
    "sample.ogg",
    "sample.oga",
    "sample.opus",
    "sample.ape",
    "sample.wv",
];

#[test]
fn fully_tagged_formats_map_every_field() {
    for name in FULLY_TAGGED {
        let tags = read(&fixture(name));
        assert_readable(&tags);
        assert_eq!(tags.title.as_deref(), Some("Test_Title"), "{name}");
        assert_eq!(tags.artist.as_deref(), Some("Artist_One"), "{name}");
        assert_eq!(tags.album.as_deref(), Some("Test_Album"), "{name}");
        assert_eq!(tags.album_artist.as_deref(), Some("Album_Artist"), "{name}");
        assert_eq!(tags.composer.as_deref(), Some("Composer_X"), "{name}");
        assert_eq!(tags.genre.as_deref(), Some("Rock"), "{name}");
        assert_eq!(tags.year, Some(2019), "{name}");
        assert_eq!(tags.track_no, Some(3), "{name}");
        assert_eq!(tags.track_total, Some(12), "{name}");
        assert_eq!(tags.disc_no, Some(1), "{name}");
        assert_eq!(tags.disc_total, Some(2), "{name}");
        assert_eq!(tags.path, fixture(name));
    }
}

#[test]
fn bitrate_is_reported_in_kbps() {
    // The MP3 fixture is encoded at 32 kbps.
    let bitrate = read(&fixture("sample_v23.mp3")).bitrate.expect("bitrate");
    assert!((24..=48).contains(&bitrate), "bitrate {bitrate}");
}

#[test]
fn id3v23_year_comes_from_tyer() {
    let tags = read(&fixture("sample_v23.mp3"));
    assert_eq!(tags.error, None);
    assert_eq!(tags.year, Some(2019));
    assert_eq!(tags.title.as_deref(), Some("Test_Title"));
    assert_eq!(tags.track_no, Some(3));
}

#[test]
fn file_type_comes_from_content_not_extension() {
    // Opus stream in an `.oga` container, ALAC with an unmapped extension and
    // an M4A named `.mp3`.
    for name in ["opus_in_ogg.oga", "sample.alac", "m4a_named.mp3"] {
        let tags = read(&fixture(name));
        assert_eq!(tags.error, None, "{name}");
        assert_eq!(tags.title.as_deref(), Some("Test_Title"), "{name}");
        assert_eq!(tags.artist.as_deref(), Some("Artist_One"), "{name}");
        assert!(tags.duration_ms.is_some(), "{name}");
    }
}

#[test]
fn id3v24_multi_value_artist_is_joined() {
    use lofty::config::WriteOptions;
    use lofty::file::TaggedFileExt;
    use lofty::prelude::*;
    use lofty::tag::{ItemKey, Tag, TagType};

    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("multi.mp3");
    fs::copy(fixture("sample.mp3"), &path).unwrap();
    let mut tag = Tag::new(TagType::Id3v2);
    tag.insert_text(ItemKey::TrackArtist, "First\0Second".to_owned());
    tag.set_comment("Written_Note".to_owned());
    tag.save_to_path(&path, WriteOptions::default()).unwrap();
    // Confirm the writer produced the layout the test is about.
    assert!(lofty::read_from_path(&path)
        .unwrap()
        .primary_tag()
        .is_some());

    let tags = read(&path.to_string_lossy());
    assert_eq!(tags.artist.as_deref(), Some("First; Second"));
    assert_eq!(tags.comment.as_deref(), Some("Written_Note"));
}

#[test]
fn wav_and_aiff_are_readable_with_basic_tags() {
    for name in ["sample.wav", "sample.aiff"] {
        let tags = read(&fixture(name));
        assert_readable(&tags);
        assert_eq!(tags.bit_depth, Some(16), "{name}");
        // RIFF INFO and AIFF text chunks only carry a few fields; the title
        // is the one every writer fills.
        assert_eq!(tags.title.as_deref(), Some("Test_Title"), "{name}");
    }
}

#[test]
fn lossless_formats_report_bit_depth() {
    for name in ["sample.flac", "sample.wv"] {
        assert_eq!(read(&fixture(name)).bit_depth, Some(16), "{name}");
    }
    // ALAC inside MP4: properties must come through even if depth is absent.
    assert_readable(&read(&fixture("sample.m4a")));
}

#[test]
fn results_keep_input_order_and_one_entry_per_path() {
    let mut paths: Vec<String> = FULLY_TAGGED.iter().map(|n| fixture(n)).collect();
    paths.insert(3, fixture("does-not-exist.mp3"));
    // Enough entries that the work is split across several threads.
    let many: Vec<String> = paths.iter().cycle().take(200).cloned().collect();
    let result = read_tags_batch(many.clone());
    assert_eq!(result.len(), many.len());
    for (input, tags) in many.iter().zip(&result) {
        assert_eq!(&tags.path, input);
    }
    assert!(result[3].error.is_some());
    assert!(result[0].error.is_none());
}

#[test]
fn empty_batch_gives_empty_result() {
    assert!(read_tags_batch(Vec::new()).is_empty());
}

#[test]
fn missing_empty_and_truncated_files_report_errors() {
    let dir = tempfile::tempdir().unwrap();
    let empty = dir.path().join("empty.flac");
    fs::write(&empty, b"").unwrap();
    let truncated = dir.path().join("truncated.flac");
    fs::write(&truncated, &fs::read(fixture("sample.flac")).unwrap()[..30]).unwrap();
    let garbage = dir.path().join("garbage.mp3");
    fs::write(&garbage, vec![0x5Au8; 4096]).unwrap();
    let unknown = dir.path().join("notes.xyz");
    fs::write(&unknown, b"hello").unwrap();

    for path in [
        &empty,
        &truncated,
        &garbage,
        &unknown,
        &dir.path().join("nope.mp3"),
    ] {
        let tags = read(&path.to_string_lossy());
        assert!(tags.error.is_some(), "{} should fail", path.display());
        assert_eq!(tags.title, None);
    }
}

#[test]
fn dsd_and_wma_are_unsupported() {
    let dir = tempfile::tempdir().unwrap();
    for name in ["a.dsf", "b.DFF", "c.wma"] {
        let path = dir.path().join(name);
        fs::write(&path, b"DSD fake content").unwrap();
        let tags = read(&path.to_string_lossy());
        assert_eq!(tags.error.as_deref(), Some("unsupported"), "{name}");
    }
}

#[test]
fn directory_is_not_a_regular_file() {
    let dir = tempfile::tempdir().unwrap();
    let named_like_audio = dir.path().join("album.flac");
    fs::create_dir(&named_like_audio).unwrap();
    let tags = read(&named_like_audio.to_string_lossy());
    assert_eq!(tags.error.as_deref(), Some("not a regular file"));
}

/// Opening a FIFO blocks until a writer appears, so the reader must reject it
/// from metadata alone. The read runs on a thread so a regression fails the
/// test with a timeout instead of hanging the suite.
#[cfg(unix)]
#[test]
fn fifo_fails_fast_without_hanging() {
    use std::ffi::CString;
    use std::os::unix::ffi::OsStrExt;

    let dir = tempfile::tempdir().unwrap();
    let fifo = dir.path().join("pipe.flac");
    let c_path = CString::new(fifo.as_os_str().as_bytes()).unwrap();
    // SAFETY: c_path is a valid NUL-terminated string that outlives the call.
    let rc = unsafe { mkfifo(c_path.as_ptr(), 0o600) };
    assert_eq!(rc, 0, "mkfifo failed");

    let (tx, rx) = mpsc::channel();
    let path = fifo.to_string_lossy().into_owned();
    std::thread::spawn(move || {
        let _ = tx.send(read_tags_batch(vec![path]));
    });
    let result = rx
        .recv_timeout(Duration::from_secs(10))
        .expect("reading a FIFO must not block");
    assert_eq!(result[0].error.as_deref(), Some("not a regular file"));
}

#[cfg(unix)]
extern "C" {
    fn mkfifo(path: *const std::ffi::c_char, mode: u32) -> i32;
}
