//! Writes cover thumbnails into the on-disk cache during a scan.
//!
//! A thumbnail is named after the blake3 hash of the **original** image bytes,
//! `<first two hex chars>/<64 hex chars>.jpg`, so files sharing a cover are
//! recognised before any decode and an album's cover is decoded once.

use std::collections::HashMap;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex, PoisonError};

use crate::api::tags::CoverStatus;
use crate::cover_art::{
    first_source, read_bounded, try_list_images, validate_header, Attempt, ImageListing,
};
use crate::cover_thumbnail::make_jpeg;

/// Prefix of in-flight temp files. The Dart cache cleanup removes leftovers
/// with this prefix, so the two must stay in sync.
pub const TEMP_PREFIX: &str = ".kanaru-tmp";

/// Cover cache of one batch: the target folder plus memos so a folder is
/// listed once and a shared `folder.jpg` is read and decoded once.
///
/// Locks are never held during IO or decoding; two threads may compute the
/// same entry, and the first insert wins. A poisoned lock is recovered, since
/// the maps only hold finished results.
pub struct CoverSink {
    dir: PathBuf,
    listings: Mutex<HashMap<PathBuf, Arc<ImageListing>>>,
    /// Sidecar path → cache key, or `None` when the image is not usable.
    sidecars: Mutex<HashMap<PathBuf, Option<String>>>,
    thumbnails_made: AtomicUsize,
    /// File name whose lookup panics (empty: every file), for tests.
    panic_for_tests: Option<String>,
}

impl CoverSink {
    /// A sink writing into `dir` (the thumbnail folder, size included).
    pub fn new(dir: impl Into<PathBuf>) -> Self {
        Self {
            dir: dir.into(),
            listings: Mutex::default(),
            sidecars: Mutex::default(),
            thumbnails_made: AtomicUsize::new(0),
            panic_for_tests: None,
        }
    }

    /// Makes [`resolve`](Self::resolve) panic, so tests can check that a crash
    /// in the cover code leaves the tags intact.
    #[doc(hidden)]
    pub fn panicking_for_tests(self) -> Self {
        self.panicking_for_tests_on("")
    }

    /// Makes [`resolve`](Self::resolve) panic for the audio file named
    /// `file_name` only, so tests can check that the rest of a batch is fine.
    #[doc(hidden)]
    pub fn panicking_for_tests_on(mut self, file_name: &str) -> Self {
        self.panic_for_tests = Some(file_name.to_owned());
        self
    }

    /// How many thumbnails this sink decoded and wrote.
    pub fn thumbnails_made(&self) -> usize {
        self.thumbnails_made.load(Ordering::Relaxed)
    }

    /// Finds the cover of `audio` and makes sure its thumbnail is cached.
    /// `embedded` are the file's pictures, best first.
    pub fn resolve(&self, audio: &Path, embedded: Vec<Vec<u8>>) -> (Option<String>, CoverStatus) {
        if let Some(name) = &self.panic_for_tests {
            let hit = name.is_empty() || audio.file_name().is_some_and(|n| n == name.as_str());
            assert!(!hit, "cover code panicked (test)");
        }
        let found = first_source(
            audio,
            embedded,
            |dir| self.listing(dir).map_err(Err),
            |bytes| attempt(self.store(&bytes)),
            |path| attempt(self.sidecar(path)),
        );
        match found {
            Some(Ok(key)) => (Some(key), CoverStatus::Found),
            Some(Err(_)) => (None, CoverStatus::Failed),
            None => (None, CoverStatus::None),
        }
    }

    /// The memoised listing of `dir`. A folder that cannot be listed is not
    /// memoised and fails the lookup, so the cover is tried again later.
    fn listing(&self, dir: &Path) -> io::Result<Arc<ImageListing>> {
        if let Some(found) = lock(&self.listings).get(dir) {
            return Ok(Arc::clone(found));
        }
        let listed = Arc::new(try_list_images(dir)?);
        Ok(Arc::clone(
            lock(&self.listings).entry(dir.to_owned()).or_insert(listed),
        ))
    }

    /// The memoised cache key of the sidecar image at `path`. A file that
    /// cannot be read is not memoised and fails the lookup, so the cover is
    /// tried again later instead of being stored as absent.
    fn sidecar(&self, path: &Path) -> io::Result<Option<String>> {
        if let Some(known) = lock(&self.sidecars).get(path) {
            return Ok(known.clone());
        }
        let key = match read_bounded(path)? {
            Some(bytes) => self.store(&bytes)?,
            None => None,
        };
        lock(&self.sidecars).insert(path.to_owned(), key.clone());
        Ok(key)
    }

    /// The cache key of `bytes`, writing the thumbnail when it is not cached
    /// yet. `Ok(None)` when the image is not usable; `Err` when the cache
    /// cannot be written.
    fn store(&self, bytes: &[u8]) -> io::Result<Option<String>> {
        let Some(format) = validate_header(bytes) else {
            return Ok(None);
        };
        let key = cache_key(bytes);
        let target = self.dir.join(&key);
        // A zero-byte file is a leftover from a crash: write it again.
        if std::fs::metadata(&target).is_ok_and(|m| m.is_file() && m.len() > 0) {
            return Ok(Some(key));
        }
        let Some(jpeg) = make_jpeg(bytes, format) else {
            return Ok(None);
        };
        self.thumbnails_made.fetch_add(1, Ordering::Relaxed);
        write_atomic(&target, &jpeg)?;
        Ok(Some(key))
    }
}

/// `<ab>/<hash>.jpg` where `hash` is the hex blake3 of the original bytes.
pub fn cache_key(original: &[u8]) -> String {
    let hash = blake3::hash(original).to_hex();
    format!("{}/{}.jpg", &hash[..2], hash.as_str())
}

/// Writes through a temp file in the target's own folder, then renames, so a
/// reader never sees a half-written thumbnail.
fn write_atomic(target: &Path, data: &[u8]) -> io::Result<()> {
    let shard = target.parent().expect("cache keys live in a shard folder");
    std::fs::create_dir_all(shard)?;
    let mut temp = tempfile::Builder::new()
        .prefix(TEMP_PREFIX)
        .tempfile_in(shard)?;
    temp.write_all(data)?;
    temp.persist(target).map_err(|e| e.error)?;
    Ok(())
}

fn attempt(result: io::Result<Option<String>>) -> Attempt<io::Result<String>> {
    match result {
        Ok(Some(key)) => Attempt::Take(Ok(key)),
        Ok(None) => Attempt::Next,
        Err(error) => Attempt::Take(Err(error)),
    }
}

fn lock<T>(mutex: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(PoisonError::into_inner)
}
