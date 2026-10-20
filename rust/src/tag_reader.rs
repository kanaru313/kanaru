//! Reads one file with lofty, guarding against files that hang or crash the
//! parser, and finds its cover in the same pass.

use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::Path;

use lofty::config::{ParseOptions, ParsingMode};
use lofty::file::{AudioFile, TaggedFileExt};
use lofty::probe::Probe;

use crate::api::tags::{CoverStatus, TrackTags};
use crate::cover_art::take_embedded_pictures;
use crate::cover_cache::CoverSink;
use crate::tag_mapping::{apply_properties, apply_tag};

/// Extensions lofty cannot parse. They are reported as unsupported instead of
/// guessed at, and the indexer keeps them as filename-only records.
const UNSUPPORTED_EXTENSIONS: [&str; 3] = ["dsf", "dff", "wma"];

/// Reads the tags of [`path`] and, when `covers` is given, its cover. Never
/// panics and never fails: every tag problem ends up in [`TrackTags::error`],
/// every cover problem in [`TrackTags::cover_status`].
///
/// A panic inside lofty is caught per file, and the cover code has its own
/// guard so a crash there never loses the tags. That relies on the default
/// `panic = "unwind"` profile setting; do not change it.
///
/// Allocation inside lofty is capped per allocation by its default
/// `GlobalOptions::allocation_limit` (16 MiB), which stops a corrupt length
/// field from asking for gigabytes. It does not bound the total: with covers
/// on, lofty loads every picture of the file. Peak memory is bounded instead
/// by the small tag thread pool and the decode limit of
/// [`make_jpeg`](crate::cover_thumbnail::make_jpeg).
pub fn read_one(path: &str, covers: Option<&CoverSink>) -> TrackTags {
    let mut parsed = guarded(path, covers.is_some());
    if covers.is_some() && parsed.is_err() {
        // Reading pictures can break a file whose tags are fine (a corrupt
        // FLAC PICTURE block, an oversized MP4 `covr`). Keep the tags; the
        // embedded cover counts as absent and sidecar images still apply.
        parsed = guarded(path, false);
    }
    let (mut tags, embedded) = match parsed {
        Ok(found) => found,
        Err(reason) => (TrackTags::failed(path.to_owned(), reason), Vec::new()),
    };

    let Some(sink) = covers else {
        tags.cover_status = CoverStatus::Skipped;
        return tags;
    };
    let audio = Path::new(path);
    // Tags of DSD/WMA files cannot be read, but a folder.jpg beside them can.
    let (cover, status) = if std::fs::metadata(audio).is_ok_and(|m| m.is_file()) {
        catch_unwind(AssertUnwindSafe(|| sink.resolve(audio, embedded)))
            .unwrap_or((None, CoverStatus::Failed))
    } else {
        (None, CoverStatus::None)
    };
    tags.cover = cover;
    tags.cover_status = status;
    tags
}

/// The embedded pictures of `path`, best first, for
/// [`read_original_cover`](crate::api::tags::read_original_cover). Empty when
/// the file cannot be parsed with pictures.
pub fn embedded_pictures(path: &str) -> Vec<Vec<u8>> {
    guarded(path, true)
        .map(|(_, pictures)| pictures)
        .unwrap_or_default()
}

fn guarded(path: &str, with_pictures: bool) -> Result<(TrackTags, Vec<Vec<u8>>), String> {
    match catch_unwind(AssertUnwindSafe(|| read_checked(path, with_pictures))) {
        Ok(result) => result,
        Err(_) => Err("tag parser panicked".to_owned()),
    }
}

fn read_checked(path: &str, with_pictures: bool) -> Result<(TrackTags, Vec<Vec<u8>>), String> {
    let file_path = Path::new(path);

    // Check before opening: opening a FIFO blocks until a writer appears, and
    // sockets or devices are never audio.
    let metadata = std::fs::metadata(file_path).map_err(|e| e.to_string())?;
    if !metadata.is_file() {
        return Err("not a regular file".to_owned());
    }

    let extension = file_path
        .extension()
        .and_then(|e| e.to_str())
        .map(str::to_ascii_lowercase)
        .unwrap_or_default();
    if UNSUPPORTED_EXTENSIONS.contains(&extension.as_str()) {
        return Err("unsupported".to_owned());
    }

    let options = ParseOptions::new()
        .read_cover_art(with_pictures)
        .parsing_mode(ParsingMode::BestAttempt);
    // Sniff the content instead of trusting the extension: `.oga` may hold
    // Opus or Speex, `.alac` is MP4, and files are often mislabeled. The
    // extension is only the fallback when the content is not recognised.
    let probe = Probe::open(file_path)
        .map_err(|e| e.to_string())?
        .options(options)
        .guess_file_type()
        .map_err(|e| e.to_string())?;
    let tagged = probe.read().map_err(|e| e.to_string())?;

    let mut tags = TrackTags {
        path: path.to_owned(),
        ..TrackTags::default()
    };
    apply_properties(&mut tags, tagged.properties());
    if let Some(tag) = tagged.primary_tag().or_else(|| tagged.first_tag()) {
        apply_tag(&mut tags, tag);
    }
    let pictures = if with_pictures {
        take_embedded_pictures(tagged)
    } else {
        Vec::new()
    };
    Ok((tags, pictures))
}
