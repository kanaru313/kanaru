//! Reads one file with lofty, guarding against files that hang or crash the
//! parser.

use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::Path;

use lofty::config::{ParseOptions, ParsingMode};
use lofty::file::{AudioFile, TaggedFileExt};
use lofty::probe::Probe;

use crate::api::tags::TrackTags;
use crate::tag_mapping::{apply_properties, apply_tag};

/// Extensions lofty cannot parse. They are reported as unsupported instead of
/// guessed at, and the indexer keeps them as filename-only records.
const UNSUPPORTED_EXTENSIONS: [&str; 3] = ["dsf", "dff", "wma"];

/// Reads the tags of [`path`]. Never panics and never fails: every problem
/// ends up in [`TrackTags::error`].
///
/// A panic inside lofty is caught per file. That relies on the default
/// `panic = "unwind"` profile setting; do not change it. Allocation inside
/// lofty is capped by its default `GlobalOptions::allocation_limit` (16 MiB),
/// so a corrupt length field cannot exhaust memory. The limit is left at its
/// default on purpose.
pub fn read_one(path: &str) -> TrackTags {
    match catch_unwind(AssertUnwindSafe(|| read_checked(path))) {
        Ok(Ok(tags)) => tags,
        Ok(Err(reason)) => TrackTags::failed(path.to_owned(), reason),
        Err(_) => TrackTags::failed(path.to_owned(), "tag parser panicked".to_owned()),
    }
}

fn read_checked(path: &str) -> Result<TrackTags, String> {
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
        .read_cover_art(false)
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
    Ok(tags)
}
