//! Reads the lyrics stored in one audio file with lofty.

use std::fs::File;
use std::io::{BufReader, Seek};
use std::path::Path;

use lofty::config::{ParseOptions, ParsingMode};
use lofty::file::{AudioFile, FileType, TaggedFile, TaggedFileExt};
use lofty::id3::v2::Id3v2Tag;
use lofty::iff::aiff::AiffFile;
use lofty::iff::wav::WavFile;
use lofty::mpeg::MpegFile;
use lofty::probe::Probe;
use lofty::tag::ItemKey;

use crate::api::lyrics::{EmbeddedLyrics, SyncedLyricLine};
use crate::lyrics_sylt::synced_lines;

/// Largest lyrics text kept, in bytes. A song's lyrics are a few KiB; a
/// larger value is junk or an attack and is dropped.
pub(crate) const MAX_LYRICS_TEXT_BYTES: usize = 1024 * 1024;

/// Opens `path` for reading without blocking: a FIFO would otherwise block
/// the open until a writer appears. The caller checks the handle's type.
/// Kept apart from the cover reader's copy so the two can change alone.
#[cfg(unix)]
fn open_nonblocking(path: &Path) -> std::io::Result<File> {
    use std::os::unix::fs::OpenOptionsExt;
    std::fs::OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NONBLOCK)
        .open(path)
}

#[cfg(not(unix))]
fn open_nonblocking(path: &Path) -> std::io::Result<File> {
    File::open(path)
}

/// The lyrics of the audio file at `path`, or `None` when it cannot be
/// read, is not a regular file, or holds none. May panic inside lofty; the
/// API wraps it.
pub(crate) fn read_lyrics(path: &str) -> Option<EmbeddedLyrics> {
    let file_path = Path::new(path);
    let file = open_nonblocking(file_path).ok()?;
    if !file.metadata().ok()?.is_file() {
        return None;
    }
    let options = ParseOptions::new()
        .read_cover_art(false)
        .read_properties(false)
        .parsing_mode(ParsingMode::BestAttempt);
    // Content first, as the tag reader does; the extension is the fallback.
    let reader = BufReader::new(file);
    let probe = match FileType::from_path(file_path) {
        Some(file_type) => Probe::with_file_type(reader, file_type),
        None => Probe::new(reader),
    };
    let probe = probe.options(options).guess_file_type().ok()?;

    // Formats whose ID3v2 tag may hold SYLT are read as their concrete type,
    // which keeps the binary frames the generic tag drops.
    let (tagged, id3v2) = match probe.file_type() {
        Some(FileType::Mpeg) => concrete::<MpegFile>(probe, options, |f| f.id3v2())?,
        Some(FileType::Wav) => concrete::<WavFile>(probe, options, |f| f.id3v2())?,
        Some(FileType::Aiff) => concrete::<AiffFile>(probe, options, |f| f.id3v2())?,
        _ => (probe.read().ok()?, Id3v2Lyrics::default()),
    };
    let text = lyrics_text(&tagged).or(id3v2.user_text);
    let synced = id3v2.synced;
    if text.is_none() && synced.is_empty() {
        return None;
    }
    Some(EmbeddedLyrics { text, synced })
}

/// What only the concrete ID3v2 tag holds: the generic tag drops binary
/// `SYLT` frames and user text frames with lyrics descriptions.
#[derive(Default)]
struct Id3v2Lyrics {
    synced: Vec<SyncedLyricLine>,
    /// `TXXX:LYRICS` or `TXXX:UNSYNCEDLYRICS`, as some taggers write.
    user_text: Option<String>,
}

impl Id3v2Lyrics {
    fn of(tag: &Id3v2Tag) -> Self {
        let user_text = ["LYRICS", "UNSYNCEDLYRICS"]
            .into_iter()
            .filter_map(|description| tag.get_user_text(description))
            .find(|text| usable_text(text))
            .map(str::to_owned);
        Self {
            synced: synced_lines(tag),
            user_text,
        }
    }
}

/// Reads the probed file as `F` and takes what its ID3v2 tag holds before
/// turning it into a generic [`TaggedFile`] (which consumes the file).
fn concrete<F>(
    probe: Probe<BufReader<File>>,
    options: ParseOptions,
    id3v2: impl Fn(&F) -> Option<&Id3v2Tag>,
) -> Option<(TaggedFile, Id3v2Lyrics)>
where
    F: AudioFile + Into<TaggedFile>,
{
    let mut reader = probe.into_inner();
    reader.rewind().ok()?;
    let file = F::read_from(&mut reader, options).ok()?;
    let lyrics = id3v2(&file).map(Id3v2Lyrics::of).unwrap_or_default();
    Some((file.into(), lyrics))
}

/// Text worth showing: not blank and within [`MAX_LYRICS_TEXT_BYTES`].
fn usable_text(text: &str) -> bool {
    text.len() <= MAX_LYRICS_TEXT_BYTES && !text.trim().is_empty()
}

/// The first usable lyrics text, looking at `Lyrics` then `UnsyncLyrics`
/// in the primary tag first, then in the other tags. Keys lofty does not
/// map (foobar2000's Vorbis `UNSYNCED LYRICS`) never reach the generic tag.
fn lyrics_text(tagged: &TaggedFile) -> Option<String> {
    let primary = tagged.primary_tag();
    let others = tagged
        .tags()
        .iter()
        .filter(|tag| Some(tag.tag_type()) != primary.map(|p| p.tag_type()));
    let tags = primary.into_iter().chain(others);
    for tag in tags {
        for key in [ItemKey::Lyrics, ItemKey::UnsyncLyrics] {
            if let Some(text) = tag.get_strings(key).find(|text| usable_text(text)) {
                return Some(text.to_owned());
            }
        }
    }
    None
}
