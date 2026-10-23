//! Lyrics reading API exposed to Dart.

use std::panic::{catch_unwind, AssertUnwindSafe};

use crate::lyrics_reader::read_lyrics;
use crate::tag_batch::WORKER_STACK_BYTES;

/// One timed line of synchronized lyrics.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct SyncedLyricLine {
    /// When the line starts, in milliseconds from the start of the track.
    pub time_ms: u32,
    pub text: String,
}

/// The lyrics stored in an audio file, from [`read_embedded_lyrics`].
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct EmbeddedLyrics {
    /// The lyrics text as stored (Vorbis `LYRICS`/`UNSYNCEDLYRICS`, ID3v2
    /// `USLT`, MP4 `©lyr`, APE `Lyrics`). May itself be LRC with time tags;
    /// the caller parses it.
    pub text: Option<String>,
    /// Lines of an ID3v2 `SYLT` frame timed in milliseconds, sorted by time;
    /// empty when the file has none.
    pub synced: Vec<SyncedLyricLine>,
}

/// The lyrics stored in the audio file at `path`, read when the track plays
/// (never during a scan). `None` when the file is gone, not a regular file
/// (a FIFO is never waited on), cannot be parsed, or holds no lyrics.
///
/// Never panics: the read runs on its own thread with the tag reader's
/// stack size, and a panic inside the parser gives `None`. Text over 1 MiB
/// and synced lines past 10 000 lines or 1 MiB are dropped.
pub fn read_embedded_lyrics(path: String) -> Option<EmbeddedLyrics> {
    std::thread::Builder::new()
        .name("kanaru-lyrics".to_owned())
        .stack_size(WORKER_STACK_BYTES)
        .spawn(move || catch_unwind(AssertUnwindSafe(|| read_lyrics(&path))).unwrap_or(None))
        .ok()?
        .join()
        .unwrap_or(None)
}
