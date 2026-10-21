//! Reads one file with lofty, guarding against files that hang or crash the
//! parser: its tags, or its embedded pictures for the cover batch.

use std::io::BufReader;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::Path;

use lofty::config::{ParseOptions, ParsingMode};
use lofty::file::{AudioFile, FileType, TaggedFileExt};
use lofty::probe::Probe;

use crate::api::tags::TrackTags;
use crate::cover_art::{open_nonblocking, take_embedded_pictures};
use crate::tag_mapping::{apply_properties, apply_tag};

/// Prefix of an [`TrackTags::error`] that reading again cannot fix (corrupt
/// or unsupported content) with this version of the reader. Anything without
/// it (an I/O or permission failure, or a mark from an older reader) may
/// pass, so the indexer tries again on every scan. The number is bumped when
/// the reader learns to read more files; keep in sync with
/// `tagReaderVersion` on the Dart side.
pub const PERMANENT_ERROR_PREFIX: &str = "permanent:v1:";

/// Extensions lofty cannot parse and that carry no tags worth reading. DSD
/// files are indexed as filename-only records without an error (the indexer
/// scans them; their folder cover still applies).
const NO_TAG_EXTENSIONS: [&str; 2] = ["dsf", "dff"];

/// Extensions lofty cannot parse that are not indexed anyway; reading one
/// directly is reported as unsupported.
const UNSUPPORTED_EXTENSIONS: [&str; 1] = ["wma"];

fn permanent(message: impl std::fmt::Display) -> String {
    format!("{PERMANENT_ERROR_PREFIX}{message}")
}

/// Parse failures are permanent unless the cause may pass: any I/O error, or
/// a file that ends early or disagrees with its own sizes, which is also what
/// a file being rewritten or a stale network cache looks like.
fn parse_error(error: &lofty::error::FileParseError) -> String {
    use lofty::error::{NotEnoughDataError, SizeMismatchError};
    use std::error::Error;
    let mut source: Option<&(dyn Error + 'static)> = Some(error);
    while let Some(current) = source {
        if current.is::<std::io::Error>()
            || current.is::<NotEnoughDataError>()
            || current.is::<SizeMismatchError>()
        {
            return error.to_string();
        }
        source = current.source();
    }
    permanent(error)
}

/// Reads the tags of [`path`], without its pictures. Never panics and never
/// fails: every problem ends up in [`TrackTags::error`]. A panic inside lofty
/// is caught per file; that relies on the default `panic = "unwind"` profile
/// setting, do not change it.
///
/// Allocation inside lofty is capped per allocation by its default
/// `GlobalOptions::allocation_limit` (16 MiB), which stops a corrupt length
/// field from asking for gigabytes.
pub fn read_one(path: &str) -> TrackTags {
    match guarded(path, false) {
        Ok((tags, _)) => tags,
        Err(reason) => TrackTags::failed(path.to_owned(), reason),
    }
}

/// The embedded pictures of `path`, best first, for
/// [`read_original_cover`](crate::api::tags::read_original_cover). Empty when
/// the file cannot be parsed with pictures.
pub fn embedded_pictures(path: &str) -> Vec<Vec<u8>> {
    embedded_pictures_result(path).unwrap_or_default()
}

/// Why the embedded pictures of a file could not be read.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CoverReadError {
    /// May pass (I/O trouble, a file that ends early or is being written, a
    /// file that is gone or not a regular file): the cover is worth looking
    /// for again later.
    Transient,
    /// The content cannot be parsed with pictures by this reader (or the
    /// parser crashed). Reading again gives the same answer, so the embedded
    /// pictures count as absent.
    Permanent,
}

/// The embedded pictures of `path`, best first, or why they could not be
/// read, classified like [`TrackTags::error`]. Never panics. A file whose
/// format carries no tags (DSD) has no pictures.
pub fn embedded_pictures_result(path: &str) -> Result<Vec<Vec<u8>>, CoverReadError> {
    match guarded(path, true) {
        Ok((_, pictures)) => Ok(pictures),
        Err(reason) if reason.starts_with(PERMANENT_ERROR_PREFIX) => Err(CoverReadError::Permanent),
        Err(_) => Err(CoverReadError::Transient),
    }
}

fn guarded(path: &str, with_pictures: bool) -> Result<(TrackTags, Vec<Vec<u8>>), String> {
    match catch_unwind(AssertUnwindSafe(|| read_checked(path, with_pictures))) {
        Ok(result) => result,
        Err(_) => Err(permanent("tag parser panicked")),
    }
}

fn read_checked(path: &str, with_pictures: bool) -> Result<(TrackTags, Vec<Vec<u8>>), String> {
    let file_path = Path::new(path);

    // Opened non-blocking and checked on the handle: opening a FIFO would
    // otherwise block until a writer appears, sockets or devices are never
    // audio, and the file read is the one that was checked.
    let file = open_nonblocking(file_path).map_err(|e| e.to_string())?;
    let metadata = file.metadata().map_err(|e| e.to_string())?;
    if !metadata.is_file() {
        return Err("not a regular file".to_owned());
    }

    let extension = file_path
        .extension()
        .and_then(|e| e.to_str())
        .map(str::to_ascii_lowercase)
        .unwrap_or_default();
    if NO_TAG_EXTENSIONS.contains(&extension.as_str()) {
        let tags = TrackTags {
            path: path.to_owned(),
            ..TrackTags::default()
        };
        return Ok((tags, Vec::new()));
    }
    if UNSUPPORTED_EXTENSIONS.contains(&extension.as_str()) {
        return Err(permanent("unsupported"));
    }

    let options = ParseOptions::new()
        .read_cover_art(with_pictures)
        .parsing_mode(ParsingMode::BestAttempt);
    // Sniff the content instead of trusting the extension: `.oga` may hold
    // Opus or Speex, `.alac` is MP4, and files are often mislabeled. The
    // extension is only the fallback when the content is not recognised.
    let reader = BufReader::new(file);
    let probe = match FileType::from_path(file_path) {
        Some(file_type) => Probe::with_file_type(reader, file_type),
        None => Probe::new(reader),
    };
    let probe = probe
        .options(options)
        .guess_file_type()
        .map_err(|e| e.to_string())?;
    let tagged = probe.read().map_err(|e| parse_error(&e))?;

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
