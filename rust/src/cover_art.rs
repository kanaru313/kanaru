//! Picks the cover image of one audio file.
//!
//! Sources, in order: pictures embedded in the tags (front covers first), then
//! an image next to the file named after it (`<stem>.jpg|jpeg|png`), then
//! `cover`, `folder`, `front` with the same extensions. Names match without
//! regard to case. A source that fails a check is skipped and the next one is
//! tried. The same order serves the scan (which writes thumbnails) and
//! [`read_original_cover`](crate::api::tags::read_original_cover).

use std::collections::HashMap;
use std::ffi::OsString;
use std::fs::File;
use std::io::{self, Cursor, Read};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::{Path, PathBuf};

use image::{ImageFormat, ImageReader};
use lofty::file::{TaggedFile, TaggedFileExt};
use lofty::picture::PictureType;
use lofty::tag::TagExt;

/// PNG and WebP images, and every image taking the full decode, are rejected
/// before any decode when a side is longer.
pub const MAX_COVER_SIDE: u32 = 4096;

/// A JPEG that is decoded scaled down (see `cover_decode_limits::scaled_plan`)
/// may have a longer side, up to this: a baseline JPEG decodes row by row at
/// 1/2, 1/4 or 1/8 size, so its memory does not grow with the picture. One that
/// would take the full decode is cut at [`MAX_COVER_SIDE`] later.
pub const MAX_SCALED_JPEG_SIDE: u32 = 8192;

/// Sidecar images larger than this are not read. Matches lofty's own
/// allocation limit for embedded pictures.
pub const MAX_COVER_BYTES: u64 = 16 * 1024 * 1024;

const SIDECAR_EXTENSIONS: [&str; 3] = ["jpg", "jpeg", "png"];
const FOLDER_NAMES: [&str; 3] = ["cover", "folder", "front"];

/// Lowercased file name → real file name, for the image files in one folder.
pub type ImageListing = HashMap<String, OsString>;

/// The format of `bytes` when it is a JPEG, PNG or WebP whose header declares
/// both sides within the limit of that format: [`MAX_SCALED_JPEG_SIDE`] for a
/// JPEG, [`MAX_COVER_SIDE`] for PNG and WebP. Nothing is decoded. Other
/// formats (GIF, BMP, TIFF, AVIF, HEIC, URL pictures) are rejected: the MIME
/// type in a tag is often wrong, so only the content counts. A header the
/// parser panics on counts as invalid.
pub fn validate_header(bytes: &[u8]) -> Option<ImageFormat> {
    let format = match bytes {
        [0xFF, 0xD8, 0xFF, ..] => ImageFormat::Jpeg,
        [0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A, ..] => ImageFormat::Png,
        [b'R', b'I', b'F', b'F', _, _, _, _, b'W', b'E', b'B', b'P', ..] => ImageFormat::WebP,
        _ => return None,
    };
    let limit = if format == ImageFormat::Jpeg {
        MAX_SCALED_JPEG_SIDE
    } else {
        MAX_COVER_SIDE
    };
    let (width, height) = catch_unwind(AssertUnwindSafe(|| {
        ImageReader::with_format(Cursor::new(bytes), format).into_dimensions()
    }))
    .ok()?
    .ok()?;
    let fits = width > 0 && height > 0 && width <= limit && height <= limit;
    fits.then_some(format)
}

/// Takes every embedded picture out of `tagged`, without copying the bytes.
/// Order: the primary tag, then the others; within that, front covers first,
/// then the rest in file order (MP4 `covr` is always `Other`).
pub fn take_embedded_pictures(mut tagged: TaggedFile) -> Vec<Vec<u8>> {
    let primary = tagged.primary_tag_type();
    let mut tag_types: Vec<_> = tagged.tags().iter().map(TagExt::tag_type).collect();
    tag_types.sort_by_key(|tag_type| *tag_type != primary);

    let mut front = Vec::new();
    let mut rest = Vec::new();
    for tag_type in tag_types {
        let Some(mut tag) = tagged.remove(tag_type) else {
            continue;
        };
        while !tag.pictures().is_empty() {
            let picture = tag.remove_picture(0);
            if picture.pic_type() == PictureType::CoverFront {
                front.push(picture.into_data());
            } else {
                rest.push(picture.into_data());
            }
        }
    }
    front.extend(rest);
    front
}

/// Lists the JPEG/PNG files in `dir`. An unreadable folder lists as empty.
pub fn list_images(dir: &Path) -> ImageListing {
    try_list_images(dir).unwrap_or_default()
}

/// Lists the JPEG/PNG files in `dir`, or fails when the folder cannot be
/// read (a cover may be there, so "no cover" would be a guess).
pub fn try_list_images(dir: &Path) -> std::io::Result<ImageListing> {
    let entries = std::fs::read_dir(dir)?;
    Ok(entries
        .filter_map(Result::ok)
        .filter_map(|entry| {
            let name = entry.file_name();
            let lower = name.to_string_lossy().to_lowercase();
            let extension = Path::new(&lower).extension()?.to_str()?;
            SIDECAR_EXTENSIONS
                .contains(&extension)
                .then(|| (lower.clone(), name))
        })
        .collect())
}

/// Sidecar images for `audio`, best first, from the listing of its folder.
pub fn sidecar_candidates(audio: &Path, listing: &ImageListing) -> Vec<PathBuf> {
    let Some(dir) = audio.parent() else {
        return Vec::new();
    };
    let stem = audio
        .file_stem()
        .map(|s| s.to_string_lossy().to_lowercase());
    stem.into_iter()
        .chain(FOLDER_NAMES.iter().map(|name| (*name).to_owned()))
        .flat_map(|base| SIDECAR_EXTENSIONS.map(|ext| format!("{base}.{ext}")))
        .filter_map(|wanted| listing.get(&wanted).map(|real| dir.join(real)))
        .collect()
}

/// Reads a sidecar image of at most [`MAX_COVER_BYTES`]. The file is opened
/// non-blocking and checked on the open handle, so a FIFO, a device, or a
/// symlink into `/proc` neither hangs nor fills memory.
///
/// `Ok(None)` when the file is gone, not a regular file, or too large: there
/// is no usable image. `Err` when it is there but cannot be opened or read
/// (permissions, a network share hiccup), so the caller can try again later.
pub fn read_bounded(path: &Path) -> io::Result<Option<Vec<u8>>> {
    read_capped(path, MAX_COVER_BYTES)
}

/// [`read_bounded`] with a cap of `max_bytes` instead of
/// [`MAX_COVER_BYTES`].
pub fn read_capped(path: &Path, max_bytes: u64) -> io::Result<Option<Vec<u8>>> {
    let file = match open_nonblocking(path) {
        Ok(file) => file,
        Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(None),
        Err(error) => return Err(error),
    };
    if !file.metadata()?.is_file() {
        return Ok(None);
    }
    let mut bytes = Vec::new();
    file.take(max_bytes + 1).read_to_end(&mut bytes)?;
    Ok((bytes.len() as u64 <= max_bytes).then_some(bytes))
}

/// Opens `path` for reading without blocking on FIFOs and devices: the open
/// returns at once, and the caller checks the handle's metadata before
/// reading. Regular files read normally.
#[cfg(unix)]
pub(crate) fn open_nonblocking(path: &Path) -> std::io::Result<File> {
    use std::os::unix::fs::OpenOptionsExt;
    std::fs::OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NONBLOCK)
        .open(path)
}

#[cfg(not(unix))]
pub(crate) fn open_nonblocking(path: &Path) -> std::io::Result<File> {
    File::open(path)
}

/// What a caller decided about one source.
pub enum Attempt<T> {
    /// Use this result and stop.
    Take(T),
    /// The source is not usable; try the next one.
    Next,
}

/// Walks the sources of `audio` in order and returns the first
/// [`Attempt::Take`]. `embedded` comes from [`take_embedded_pictures`];
/// `listing` gives the image files of the audio file's folder (memoised by
/// the scan, listed fresh otherwise), or the result to return when the folder
/// cannot be listed.
pub fn first_source<T>(
    audio: &Path,
    embedded: Vec<Vec<u8>>,
    listing: impl FnOnce(&Path) -> Result<std::sync::Arc<ImageListing>, T>,
    mut try_embedded: impl FnMut(Vec<u8>) -> Attempt<T>,
    mut try_sidecar: impl FnMut(&Path) -> Attempt<T>,
) -> Option<T> {
    for bytes in embedded {
        if let Attempt::Take(result) = try_embedded(bytes) {
            return Some(result);
        }
    }
    let dir = audio.parent()?;
    let listing = match listing(dir) {
        Ok(listing) => listing,
        Err(result) => return Some(result),
    };
    for candidate in sidecar_candidates(audio, &listing) {
        if let Attempt::Take(result) = try_sidecar(&candidate) {
            return Some(result);
        }
    }
    None
}
