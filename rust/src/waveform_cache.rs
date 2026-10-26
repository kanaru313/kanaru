//! On-disk cache of waveform levels, one small file per audio file version.
//!
//! The name is the hex blake3 of the path, size, modification time, change
//! time and inode, plus `.kwf`; any edit, move or `touch -r` re-tag gives a
//! new name, so old entries are never wrong, only orphaned.
//!
//! File layout (little endian): `KNWF`, version `u8`, kind `u8` (0 levels,
//! 1 negative), two zero bytes, sample rate `u32`, frames `u64`, level count
//! `u32`, then the levels. A negative entry records that decoding this exact
//! file version failed for good, so it is not tried again on every play.
//!
//! The folder is kept bounded by `waveform_cache_sweep`.

use std::fs::{File, Metadata};
use std::io::{self, Read};
use std::path::Path;

use crate::cover_cache::write_atomic;
use crate::waveform_cache_sweep::note_write;
use crate::waveform_levels::MAX_LEVELS;

const MAGIC: &[u8; 4] = b"KNWF";
/// Bump when the level scale or the layout changes; older files are ignored.
const VERSION: u8 = 1;
const HEADER_LEN: usize = 24;
/// Most levels a file may claim, a little above [`MAX_LEVELS`].
const MAX_COUNT: usize = 4096;

/// What a cache file says about one audio file version.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CacheEntry {
    Levels {
        levels: Vec<u8>,
        frames: u64,
        sample_rate: u32,
    },
    /// Decoding failed for good (broken stream, limits).
    Negative,
}

/// Cache file name for the audio file at `path` with `meta` (from the same
/// `stat` call the caller used to check it is a regular file).
pub fn cache_key(path: &Path, meta: &Metadata) -> String {
    key_for(path, identity(meta))
}

fn key_for(path: &Path, identity: [i128; 4]) -> String {
    let mut hasher = blake3::Hasher::new();
    hasher.update(path_bytes(path));
    for part in identity {
        hasher.update(&[0]);
        hasher.update(part.to_string().as_bytes());
    }
    format!("{}.kwf", hasher.finalize().to_hex())
}

#[cfg(unix)]
fn path_bytes(path: &Path) -> &[u8] {
    use std::os::unix::ffi::OsStrExt;
    path.as_os_str().as_bytes()
}

#[cfg(not(unix))]
fn path_bytes(path: &Path) -> &[u8] {
    path.to_str().unwrap_or_default().as_bytes()
}

/// Size, mtime, ctime (nanoseconds) and inode. ctime and inode are what
/// catch a re-tag that restored the old mtime.
#[cfg(unix)]
fn identity(meta: &Metadata) -> [i128; 4] {
    use std::os::unix::fs::MetadataExt;
    let nanos = |secs: i64, nsec: i64| i128::from(secs) * 1_000_000_000 + i128::from(nsec);
    [
        i128::from(meta.len()),
        nanos(meta.mtime(), meta.mtime_nsec()),
        nanos(meta.ctime(), meta.ctime_nsec()),
        i128::from(meta.ino()),
    ]
}

#[cfg(not(unix))]
fn identity(meta: &Metadata) -> [i128; 4] {
    let mtime = meta
        .modified()
        .ok()
        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
        .map_or(0, |d| d.as_nanos() as i128);
    [i128::from(meta.len()), mtime, 0, 0]
}

/// Opens a cache file without blocking and without following a symlink, so a
/// FIFO or link put at the name is never waited on or followed.
#[cfg(unix)]
fn open_cache_file(path: &Path) -> io::Result<File> {
    use std::os::unix::fs::OpenOptionsExt;
    File::options()
        .read(true)
        .custom_flags(libc::O_NONBLOCK | libc::O_NOFOLLOW)
        .open(path)
}

#[cfg(not(unix))]
fn open_cache_file(path: &Path) -> io::Result<File> {
    File::open(path)
}

/// The entry stored under `key` in `dir`, or `None` when there is none or it
/// is not valid. The handle must be a regular file of plausible size (checked
/// on the open handle), and no more than that size is read.
pub fn read(dir: &Path, key: &str) -> Option<CacheEntry> {
    let file = open_cache_file(&dir.join(key)).ok()?;
    let meta = file.metadata().ok()?;
    if !meta.is_file() || meta.len() > (HEADER_LEN + MAX_COUNT) as u64 {
        return None;
    }
    let mut bytes = Vec::with_capacity(meta.len() as usize);
    file.take((HEADER_LEN + MAX_COUNT + 1) as u64)
        .read_to_end(&mut bytes)
        .ok()?;
    decode(&bytes)
}

/// Writes `entry` under `key` in `dir` (created if missing) through a temp
/// file and a rename.
pub fn write(dir: &Path, key: &str, entry: &CacheEntry) -> io::Result<()> {
    write_atomic(&dir.join(key), &encode(entry))
}

/// Where the cache entry of one audio file version lives.
pub struct CacheSlot<'a> {
    dir: &'a Path,
    key: String,
}

impl<'a> CacheSlot<'a> {
    /// The slot for the audio file at `path` with `meta` in the cache folder
    /// `dir`; `None` when `dir` is empty (no cache).
    pub fn new(dir: &'a str, path: &Path, meta: &Metadata) -> Option<Self> {
        (!dir.is_empty()).then(|| Self {
            dir: Path::new(dir),
            key: cache_key(path, meta),
        })
    }
}

/// Returns `hit(entry)` when the slot holds a valid entry. Otherwise runs
/// `compute`, stores the entry it offers (a failed write is reported once,
/// without the path, and does not change the result) and returns its result.
pub fn lookup_or_store<R>(
    slot: Option<&CacheSlot<'_>>,
    hit: impl FnOnce(CacheEntry) -> R,
    compute: impl FnOnce() -> (R, Option<CacheEntry>),
) -> R {
    if let Some(entry) = slot.and_then(|s| read(s.dir, &s.key)) {
        return hit(entry);
    }
    let (result, entry) = compute();
    if let (Some(slot), Some(entry)) = (slot, entry) {
        match write(slot.dir, &slot.key, &entry) {
            Ok(()) => note_write(slot.dir),
            Err(error) => {
                static WRITE_REPORTED: std::sync::Once = std::sync::Once::new();
                WRITE_REPORTED.call_once(|| {
                    eprintln!("kanaru: cannot write the waveform cache: {}", error.kind());
                });
            }
        }
    }
    result
}

fn encode(entry: &CacheEntry) -> Vec<u8> {
    let (kind, rate, frames, levels): (u8, u32, u64, &[u8]) = match entry {
        CacheEntry::Levels {
            levels,
            frames,
            sample_rate,
        } => (0, *sample_rate, *frames, levels),
        CacheEntry::Negative => (1, 0, 0, &[]),
    };
    let mut out = Vec::with_capacity(HEADER_LEN + levels.len());
    out.extend_from_slice(MAGIC);
    out.extend_from_slice(&[VERSION, kind, 0, 0]);
    out.extend_from_slice(&rate.to_le_bytes());
    out.extend_from_slice(&frames.to_le_bytes());
    out.extend_from_slice(&(levels.len() as u32).to_le_bytes());
    out.extend_from_slice(levels);
    out
}

fn decode(bytes: &[u8]) -> Option<CacheEntry> {
    if bytes.len() < HEADER_LEN || &bytes[..4] != MAGIC || bytes[4] != VERSION {
        return None;
    }
    let kind = bytes[5];
    let sample_rate = u32::from_le_bytes(bytes[8..12].try_into().ok()?);
    let frames = u64::from_le_bytes(bytes[12..20].try_into().ok()?);
    let count = u32::from_le_bytes(bytes[20..24].try_into().ok()?) as usize;
    if count > MAX_COUNT.max(MAX_LEVELS) || bytes.len() != HEADER_LEN + count {
        return None;
    }
    match kind {
        0 if count > 0 && sample_rate > 0 => Some(CacheEntry::Levels {
            levels: bytes[HEADER_LEN..].to_vec(),
            frames,
            sample_rate,
        }),
        1 if count == 0 => Some(CacheEntry::Negative),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    fn levels() -> CacheEntry {
        CacheEntry::Levels {
            levels: vec![0, 10, 255, 7],
            frames: 96_000,
            sample_rate: 48_000,
        }
    }

    #[test]
    fn both_kinds_round_trip() {
        let dir = TempDir::new().unwrap();
        write(dir.path(), "a.kwf", &levels()).unwrap();
        write(dir.path(), "b.kwf", &CacheEntry::Negative).unwrap();
        assert_eq!(read(dir.path(), "a.kwf"), Some(levels()));
        assert_eq!(read(dir.path(), "b.kwf"), Some(CacheEntry::Negative));
        assert_eq!(read(dir.path(), "missing.kwf"), None);
    }

    #[test]
    fn every_rejection_rule_gives_a_miss() {
        let good = encode(&levels());
        let mutate = |f: &dyn Fn(&mut Vec<u8>)| {
            let mut bytes = good.clone();
            f(&mut bytes);
            decode(&bytes)
        };
        assert!(decode(&good).is_some());
        assert_eq!(mutate(&|b| b[0] = b'X'), None, "magic");
        assert_eq!(mutate(&|b| b[4] = 0), None, "version 0");
        assert_eq!(mutate(&|b| b[4] = 2), None, "future version");
        assert_eq!(mutate(&|b| b[5] = 2), None, "unknown kind");
        assert_eq!(mutate(&|b| b[8..12].fill(0)), None, "zero rate");
        assert_eq!(mutate(&|b| b[20..24].fill(0)), None, "levels without count");
        assert_eq!(mutate(&|b| b[20] = 5), None, "count above data");
        assert_eq!(mutate(&|b| b.push(1)), None, "trailing byte");
        assert_eq!(mutate(&|b| b.truncate(10)), None, "truncated header");
        assert_eq!(mutate(&|b| b.truncate(26)), None, "truncated levels");
        let mut huge = good.clone();
        huge[20..24].copy_from_slice(&5000u32.to_le_bytes());
        huge.resize(HEADER_LEN + 5000, 1);
        assert_eq!(decode(&huge), None, "count above the limit");
        let mut negative = encode(&CacheEntry::Negative);
        negative.push(3);
        negative[20] = 1;
        assert_eq!(decode(&negative), None, "negative with levels");
    }

    #[test]
    fn a_fifo_a_symlink_or_an_oversize_file_at_the_key_is_a_miss() {
        let dir = TempDir::new().unwrap();
        let outside = dir.path().join("real");
        write(dir.path(), "real", &levels()).unwrap();
        std::os::unix::fs::symlink(&outside, dir.path().join("link.kwf")).unwrap();
        assert_eq!(read(dir.path(), "link.kwf"), None);

        let fifo = std::ffi::CString::new(dir.path().join("pipe.kwf").to_str().unwrap()).unwrap();
        // SAFETY: valid NUL-terminated path that outlives the call.
        assert_eq!(unsafe { libc::mkfifo(fifo.as_ptr(), 0o600) }, 0);
        assert_eq!(read(dir.path(), "pipe.kwf"), None);

        std::fs::write(
            dir.path().join("big.kwf"),
            vec![0u8; HEADER_LEN + MAX_COUNT + 1],
        )
        .unwrap();
        assert_eq!(read(dir.path(), "big.kwf"), None);
    }

    #[test]
    fn the_key_changes_with_every_part_of_the_file_identity() {
        let path = Path::new("/music/song.flac");
        let base = [1000, 2_000_000_000, 3_000_000_000, 42];
        let key = key_for(path, base);
        assert_eq!(key, key_for(path, base), "stable");
        assert!(key.ends_with(".kwf") && key.len() == 64 + 4);
        for part in 0..4 {
            let mut changed = base;
            changed[part] += 1;
            assert_ne!(key, key_for(path, changed), "part {part}");
        }
        assert_ne!(key, key_for(Path::new("/music/other.flac"), base), "path");
    }

    #[test]
    fn a_retag_that_restores_the_old_mtime_still_changes_the_key() {
        let dir = TempDir::new().unwrap();
        let file = dir.path().join("song.flac");
        std::fs::write(&file, b"one").unwrap();
        let before = std::fs::metadata(&file).unwrap();
        let first = cache_key(&file, &before);
        std::thread::sleep(std::time::Duration::from_millis(20));
        // Same size, content changed, old mtime put back (`touch -r`).
        std::fs::write(&file, b"two").unwrap();
        File::options()
            .write(true)
            .open(&file)
            .unwrap()
            .set_modified(before.modified().unwrap())
            .unwrap();
        let after = std::fs::metadata(&file).unwrap();
        assert_eq!(before.len(), after.len());
        assert_ne!(first, cache_key(&file, &after));
    }
}
