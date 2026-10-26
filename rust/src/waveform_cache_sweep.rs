//! Keeps the waveform cache folder bounded.
//!
//! A sweep deletes, in `<cache>/waveforms`:
//! - temp files (`cover_cache::TEMP_PREFIX`) older than 5 minutes, left by a
//!   crash between the temp write and the rename;
//! - entries (`<64 lowercase hex>.kwf`) not used for 90 days (a cache hit
//!   refreshes the modification time), which covers orphans of edited or moved
//!   files and files of an older format;
//! - the least recently used entries once more than 20 000 remain, down to
//!   18 000.
//!
//! Only regular files with those exact names are touched; sub-folders, links,
//! FIFOs and any other name stay. The folder must be absolute and owned by
//! the effective user, whether reached through a link or not, so a folder
//! planted by someone else is never emptied. The folder is listed completely
//! (at most `max_listed` matches) before anything is deleted, and each file
//! is looked at again right before its unlink and kept if it changed since.
//! A write that lands between that look and the unlink costs one decode.
//! The owner check and the later listing and deletes resolve the path
//! separately. That is accepted: swapping the folder in between needs write
//! access to the user's own cache folder, and only exact-name entries can be
//! removed.
//!
//! The job thread runs a sweep after it has sent its result: at the first job
//! of a run, 24 hours after the last sweep, and when the estimated entry
//! count passes a threshold. One sweep per folder at a time. Failures are
//! reported once, by kind, never with a path.

use std::collections::{HashMap, HashSet};
use std::fs;
use std::io;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::{Path, PathBuf};
use std::sync::{Mutex, MutexGuard, Once, PoisonError};
use std::time::{Duration, Instant, SystemTime};

use crate::cover_cache::TEMP_PREFIX;

const ENTRY_SUFFIX: &str = ".kwf";
/// 64 hex characters of a blake3 hash plus the suffix.
const ENTRY_NAME_LEN: usize = 64 + ENTRY_SUFFIX.len();

/// What a sweep keeps and when it runs.
#[derive(Debug, Clone, Copy)]
pub(crate) struct SweepLimits {
    /// More entries than this start an eviction.
    pub max_entries: usize,
    /// Eviction stops at this many entries.
    pub keep_entries: usize,
    /// Most matching files read from the listing.
    pub max_listed: usize,
    /// Entries older than this are deleted.
    pub max_idle: Duration,
    /// Temp files older than this are deleted.
    pub temp_age: Duration,
    /// Time after which the next claim wins again.
    pub resweep_after: Duration,
    /// How far in the future a modification time may be before it counts as a
    /// wrong clock (and the entry as idle).
    pub future_slack: Duration,
}

pub(crate) const LIMITS: SweepLimits = SweepLimits {
    max_entries: 20_000,
    keep_entries: 18_000,
    max_listed: 80_000,
    max_idle: Duration::from_secs(90 * 24 * 3600),
    temp_age: Duration::from_secs(5 * 60),
    resweep_after: Duration::from_secs(24 * 3600),
    future_slack: Duration::from_secs(24 * 3600),
};

#[derive(Clone, Copy, PartialEq, Eq)]
enum Kind {
    Temp,
    Entry,
}

struct Item {
    name: String,
    kind: Kind,
    modified: SystemTime,
}

/// Name of a file the sweep may delete, by exact pattern.
fn kind_of(name: &str) -> Option<Kind> {
    if name.starts_with(TEMP_PREFIX) {
        return Some(Kind::Temp);
    }
    let hex = name.strip_suffix(ENTRY_SUFFIX)?;
    let is_hash = name.len() == ENTRY_NAME_LEN
        && hex
            .bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b));
    is_hash.then_some(Kind::Entry)
}

/// The folder is absolute and owned by the effective user, itself and, when
/// it is a link, the link too. `Ok(false)` when it does not exist.
#[cfg(unix)]
fn folder_is_ours(dir: &Path) -> io::Result<bool> {
    use std::os::unix::fs::MetadataExt;
    if !dir.is_absolute() {
        return Err(io::ErrorKind::InvalidInput.into());
    }
    let followed = match fs::metadata(dir) {
        Ok(meta) => meta,
        Err(e) if e.kind() == io::ErrorKind::NotFound => return Ok(false),
        Err(e) => return Err(e),
    };
    // SAFETY: geteuid has no preconditions and cannot fail.
    let uid = unsafe { libc::geteuid() };
    if !followed.is_dir() {
        return Err(io::ErrorKind::InvalidInput.into());
    }
    let link = fs::symlink_metadata(dir)?;
    if followed.uid() != uid || link.uid() != uid {
        return Err(io::ErrorKind::PermissionDenied.into());
    }
    Ok(true)
}

#[cfg(not(unix))]
fn folder_is_ours(dir: &Path) -> io::Result<bool> {
    match fs::metadata(dir) {
        Ok(meta) if meta.is_dir() => Ok(true),
        Ok(_) => Err(io::ErrorKind::InvalidInput.into()),
        Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(false),
        Err(e) => Err(e),
    }
}

/// Matching regular files of `dir`, at most `limit`, each name once. The
/// listing is closed before this returns.
fn collect(dir: &Path, limit: usize) -> io::Result<Vec<Item>> {
    let mut items = Vec::new();
    let mut seen = HashSet::new();
    let listing = match fs::read_dir(dir) {
        Ok(listing) => listing,
        // Removed after the owner check: nothing to sweep.
        Err(e) if e.kind() == io::ErrorKind::NotFound => return Ok(items),
        Err(e) => return Err(e),
    };
    for entry in listing {
        if items.len() >= limit {
            break;
        }
        // A file that vanished or cannot be read is skipped.
        let Ok(entry) = entry else { continue };
        let Ok(name) = entry.file_name().into_string() else {
            continue;
        };
        let Some(kind) = kind_of(&name) else { continue };
        // `file_type` and `metadata` of a `DirEntry` do not follow links.
        if !entry.file_type().is_ok_and(|t| t.is_file()) {
            continue;
        }
        let Ok(modified) = entry.metadata().and_then(|m| m.modified()) else {
            continue;
        };
        if seen.insert(name.clone()) {
            items.push(Item {
                name,
                kind,
                modified,
            });
        }
    }
    Ok(items)
}

/// Names to delete, from the listing: stale temps, idle entries, then the
/// oldest of the rest above the cap.
fn doomed<'a>(items: &'a [Item], limits: &SweepLimits, now: SystemTime) -> Vec<&'a Item> {
    let mut doomed = Vec::new();
    let mut live = Vec::new();
    for item in items {
        let stale = match item.kind {
            Kind::Temp => age(now, item.modified) > limits.temp_age,
            Kind::Entry => {
                let ahead = item.modified.duration_since(now).unwrap_or(Duration::ZERO);
                ahead > limits.future_slack || age(now, item.modified) > limits.max_idle
            }
        };
        if stale {
            doomed.push(item);
        } else if item.kind == Kind::Entry {
            live.push(item);
        }
    }
    if live.len() > limits.max_entries {
        live.sort_by(|a, b| (a.modified, &a.name).cmp(&(b.modified, &b.name)));
        let excess = live.len().saturating_sub(limits.keep_entries);
        doomed.extend(live.into_iter().take(excess));
    }
    doomed
}

/// Time since `modified`; zero for a time in the future.
fn age(now: SystemTime, modified: SystemTime) -> Duration {
    now.duration_since(modified).unwrap_or(Duration::ZERO)
}

/// Unlinks `item` when it is still the regular file that was listed.
/// True when it is gone afterwards.
fn remove_if_unchanged(dir: &Path, item: &Item) -> bool {
    let path = dir.join(&item.name);
    match fs::symlink_metadata(&path) {
        Ok(meta) if meta.is_file() && meta.modified().is_ok_and(|m| m == item.modified) => {
            match fs::remove_file(&path) {
                Ok(()) => true,
                Err(e) => e.kind() == io::ErrorKind::NotFound,
            }
        }
        Ok(_) => false,
        Err(e) => e.kind() == io::ErrorKind::NotFound,
    }
}

/// Sweeps `dir` as of `now` and returns how many entries are left. A missing
/// folder is empty. A folder that is not ours or cannot be listed is an
/// error and nothing is deleted.
pub(crate) fn sweep(dir: &Path, limits: &SweepLimits, now: SystemTime) -> io::Result<usize> {
    if !folder_is_ours(dir)? {
        return Ok(0);
    }
    let items = collect(dir, limits.max_listed)?;
    let gone: HashSet<&str> = doomed(&items, limits, now)
        .into_iter()
        .filter(|item| remove_if_unchanged(dir, item))
        .map(|item| item.name.as_str())
        .collect();
    Ok(items
        .iter()
        .filter(|i| i.kind == Kind::Entry && !gone.contains(i.name.as_str()))
        .count())
}

// --- When to sweep -------------------------------------------------------

/// Per folder: the sweep state of this process.
struct DirState {
    swept_at: Option<Instant>,
    running: bool,
    /// Entries believed to be in the folder (kept by the last sweep plus the
    /// writes since).
    estimate: usize,
    /// The estimate above which the next claim wins.
    threshold: usize,
    /// The last sweep failed: only the time rule re-arms.
    failed: bool,
}

impl DirState {
    fn new(limits: &SweepLimits) -> Self {
        Self {
            swept_at: None,
            running: false,
            estimate: 0,
            threshold: limits.max_entries,
            failed: false,
        }
    }
}

/// Starts a sweep when none runs and this is the first, the last one is old
/// enough, or the estimate passed the threshold. Returns the estimate at the
/// start.
fn claim_rule(state: &mut DirState, limits: &SweepLimits, now: Instant) -> Option<usize> {
    if state.running {
        return None;
    }
    let due = match state.swept_at {
        None => true,
        Some(at) => {
            now.saturating_duration_since(at) >= limits.resweep_after
                || (!state.failed && state.estimate > state.threshold)
        }
    };
    due.then(|| {
        state.running = true;
        state.estimate
    })
}

/// Ends a sweep. `kept` is `None` when it failed.
fn end_rule(
    state: &mut DirState,
    limits: &SweepLimits,
    kept: Option<usize>,
    estimate_at_claim: usize,
    now: Instant,
) {
    state.running = false;
    state.swept_at = Some(now);
    match kept {
        Some(kept) => {
            let writes = state.estimate.saturating_sub(estimate_at_claim);
            state.estimate = kept + writes;
            // Failed deletes: back off by the eviction step (max - keep), so
            // the folder passes ~max_entries only when deletes failed.
            state.threshold = if kept > limits.max_entries {
                kept + (limits.max_entries - limits.keep_entries)
            } else {
                limits.max_entries
            };
            state.failed = false;
        }
        None => state.failed = true,
    }
}

static DIRS: Mutex<Option<HashMap<PathBuf, DirState>>> = Mutex::new(None);

fn with_state<R>(dir: &Path, f: impl FnOnce(&mut DirState) -> R) -> R {
    let mut guard: MutexGuard<'_, _> = DIRS.lock().unwrap_or_else(PoisonError::into_inner);
    let state = guard
        .get_or_insert_with(HashMap::new)
        .entry(dir.to_path_buf())
        .or_insert_with(|| DirState::new(&LIMITS));
    f(state)
}

/// Counts one entry written to `dir`.
pub(crate) fn note_write(dir: &Path) {
    with_state(dir, |state| state.estimate += 1);
}

/// A sweep this caller may run. Dropping it unfinished (a panic) lets the
/// next claim win again.
pub(crate) struct SweepTicket {
    dir: PathBuf,
    estimate_at_claim: usize,
    done: bool,
}

/// The ticket for `dir` when a sweep is due and none runs. The lock is
/// released before the ticket is built.
pub(crate) fn claim(dir: &Path) -> Option<SweepTicket> {
    let estimate = with_state(dir, |state| claim_rule(state, &LIMITS, Instant::now()))?;
    Some(SweepTicket {
        dir: dir.to_path_buf(),
        estimate_at_claim: estimate,
        done: false,
    })
}

impl SweepTicket {
    /// Sweeps the folder and records the outcome. A failure or panic of the
    /// sweep is reported once, by kind, and delays the next sweep by a day.
    pub(crate) fn run(mut self) {
        static REPORTED: Once = Once::new();
        let outcome = catch_unwind(AssertUnwindSafe(|| {
            sweep(&self.dir, &LIMITS, SystemTime::now())
        }));
        let kept = match outcome {
            Ok(Ok(kept)) => Some(kept),
            Ok(Err(error)) => {
                REPORTED.call_once(|| {
                    eprintln!("kanaru: cannot clean the waveform cache: {}", error.kind());
                });
                None
            }
            Err(_) => {
                REPORTED.call_once(|| {
                    eprintln!("kanaru: cannot clean the waveform cache: panic");
                });
                None
            }
        };
        let estimate_at_claim = self.estimate_at_claim;
        with_state(&self.dir, |state| {
            end_rule(state, &LIMITS, kept, estimate_at_claim, Instant::now());
        });
        self.done = true;
    }
}

impl Drop for SweepTicket {
    fn drop(&mut self) {
        if !self.done {
            with_state(&self.dir, |state| state.running = false);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::File;
    use std::os::unix::fs::PermissionsExt;
    use tempfile::TempDir;

    const DAY: Duration = Duration::from_secs(24 * 3600);

    fn small() -> SweepLimits {
        SweepLimits {
            max_entries: 3,
            keep_entries: 2,
            max_listed: 10,
            ..LIMITS
        }
    }

    fn name(c: char) -> String {
        format!("{}{ENTRY_SUFFIX}", c.to_string().repeat(64))
    }

    /// Creates a regular file `name` last modified at `modified`.
    fn put(dir: &Path, name: &str, modified: SystemTime) {
        fs::write(dir.join(name), b"x").unwrap();
        File::options()
            .write(true)
            .open(dir.join(name))
            .unwrap()
            .set_modified(modified)
            .unwrap();
    }

    fn exists(dir: &Path, name: &str) -> bool {
        fs::symlink_metadata(dir.join(name)).is_ok()
    }

    fn files(dir: &Path) -> usize {
        fs::read_dir(dir).unwrap().count()
    }

    #[test]
    fn a_stale_temp_goes_and_a_fresh_one_stays() {
        let dir = TempDir::new().unwrap();
        let now = SystemTime::now();
        put(dir.path(), ".kanaru-tmpOLD", now - Duration::from_secs(301));
        put(dir.path(), ".kanaru-tmpNEW", now - Duration::from_secs(299));
        assert_eq!(sweep(dir.path(), &LIMITS, now).unwrap(), 0);
        assert!(!exists(dir.path(), ".kanaru-tmpOLD"));
        assert!(exists(dir.path(), ".kanaru-tmpNEW"));
    }

    #[test]
    fn an_idle_entry_goes_and_a_fresh_one_stays() {
        let dir = TempDir::new().unwrap();
        let now = SystemTime::now();
        put(dir.path(), &name('a'), now - 91 * DAY);
        put(dir.path(), &name('b'), now - 89 * DAY);
        assert_eq!(sweep(dir.path(), &LIMITS, now).unwrap(), 1);
        assert!(!exists(dir.path(), &name('a')));
        assert!(exists(dir.path(), &name('b')));
    }

    #[test]
    fn above_the_cap_the_oldest_go_down_to_the_keep_count() {
        let dir = TempDir::new().unwrap();
        let now = SystemTime::now();
        for (i, c) in ['a', 'b', 'c', 'd', 'e'].into_iter().enumerate() {
            // 'a' is the newest, 'e' the oldest.
            put(dir.path(), &name(c), now - DAY * (i as u32 + 1));
        }
        assert_eq!(sweep(dir.path(), &small(), now).unwrap(), 2);
        assert!(exists(dir.path(), &name('a')) && exists(dir.path(), &name('b')));
        for c in ['c', 'd', 'e'] {
            assert!(!exists(dir.path(), &name(c)), "{c}");
        }
    }

    #[test]
    fn equal_times_are_evicted_by_name() {
        let dir = TempDir::new().unwrap();
        let now = SystemTime::now();
        let same = now - DAY;
        for c in ['a', 'b', 'c', 'd'] {
            put(dir.path(), &name(c), same);
        }
        assert_eq!(sweep(dir.path(), &small(), now).unwrap(), 2);
        assert!(!exists(dir.path(), &name('a')) && !exists(dir.path(), &name('b')));
        assert!(exists(dir.path(), &name('c')) && exists(dir.path(), &name('d')));
    }

    #[test]
    fn exactly_the_cap_evicts_nothing() {
        let dir = TempDir::new().unwrap();
        let now = SystemTime::now();
        for c in ['a', 'b', 'c'] {
            put(dir.path(), &name(c), now - DAY);
        }
        assert_eq!(sweep(dir.path(), &small(), now).unwrap(), 3);
        assert_eq!(files(dir.path()), 3);
    }

    #[test]
    fn only_exact_names_of_regular_files_are_ever_deleted() {
        let dir = TempDir::new().unwrap();
        let outside = TempDir::new().unwrap();
        let target = outside.path().join("target");
        fs::write(&target, b"keep").unwrap();
        let p = dir.path();
        let long_ago = SystemTime::now() - 500 * DAY;
        put(p, "notes.txt", long_ago);
        put(p, &format!("{}{ENTRY_SUFFIX}", "e".repeat(63)), long_ago);
        put(p, &format!("{}{ENTRY_SUFFIX}", "A".repeat(64)), long_ago);
        put(p, &format!("{}.kwf.bak", "f".repeat(64)), long_ago);
        fs::create_dir(p.join(name('c'))).unwrap();
        fs::write(p.join(name('c')).join("inner"), b"x").unwrap();
        fs::create_dir(p.join(".kanaru-tmpDIR")).unwrap();
        std::os::unix::fs::symlink(&target, p.join(name('b'))).unwrap();
        std::os::unix::fs::symlink(&target, p.join(".kanaru-tmpLINK")).unwrap();
        let fifo = std::ffi::CString::new(p.join(name('d')).to_str().unwrap()).unwrap();
        // SAFETY: valid NUL-terminated path that outlives the call.
        assert_eq!(unsafe { libc::mkfifo(fifo.as_ptr(), 0o600) }, 0);
        // Controls: real files that must go with a far-future clock.
        put(p, &name('0'), long_ago);
        put(p, ".kanaru-tmpCONTROL", long_ago);

        let decoys = files(p) - 2;
        let now = SystemTime::now() + 400 * DAY;
        sweep(p, &small(), now).unwrap();

        assert!(!exists(p, &name('0')) && !exists(p, ".kanaru-tmpCONTROL"));
        assert_eq!(files(p), decoys);
        assert_eq!(fs::read(&target).unwrap(), b"keep");
        assert!(fs::symlink_metadata(p.join(name('b')))
            .unwrap()
            .file_type()
            .is_symlink());
        assert!(p.join(name('c')).join("inner").exists());
    }

    #[test]
    fn a_missing_folder_is_empty() {
        let dir = TempDir::new().unwrap();
        let missing = dir.path().join("none");
        assert_eq!(sweep(&missing, &LIMITS, SystemTime::now()).unwrap(), 0);
    }

    #[test]
    fn a_file_in_place_of_the_folder_is_refused() {
        let dir = TempDir::new().unwrap();
        let file = dir.path().join("waveforms");
        fs::write(&file, b"x").unwrap();
        let error = sweep(&file, &LIMITS, SystemTime::now()).unwrap_err();
        assert_eq!(error.kind(), io::ErrorKind::InvalidInput);
    }

    #[test]
    fn a_link_to_our_folder_is_followed_and_swept() {
        let dir = TempDir::new().unwrap();
        let real = dir.path().join("real");
        fs::create_dir(&real).unwrap();
        put(&real, &name('a'), SystemTime::now() - 500 * DAY);
        let link = dir.path().join("link");
        std::os::unix::fs::symlink(&real, &link).unwrap();
        assert_eq!(sweep(&link, &LIMITS, SystemTime::now()).unwrap(), 0);
        assert!(!exists(&real, &name('a')));
    }

    #[test]
    fn a_relative_folder_is_refused() {
        let error = sweep(Path::new("waveforms"), &LIMITS, SystemTime::now()).unwrap_err();
        assert_eq!(error.kind(), io::ErrorKind::InvalidInput);
    }

    /// Puts the folder back to readable even when an assert fails.
    struct Restore(PathBuf);
    impl Drop for Restore {
        fn drop(&mut self) {
            let _ = fs::set_permissions(&self.0, fs::Permissions::from_mode(0o755));
        }
    }

    #[test]
    fn a_folder_that_cannot_be_listed_is_an_error() {
        // SAFETY: geteuid has no preconditions.
        if unsafe { libc::geteuid() } == 0 {
            return; // root lists anything
        }
        let dir = TempDir::new().unwrap();
        let _restore = Restore(dir.path().to_path_buf());
        put(dir.path(), &name('a'), SystemTime::now() - 500 * DAY);
        fs::set_permissions(dir.path(), fs::Permissions::from_mode(0o000)).unwrap();
        let result = sweep(dir.path(), &LIMITS, SystemTime::now());
        fs::set_permissions(dir.path(), fs::Permissions::from_mode(0o755)).unwrap();
        assert!(result.is_err());
        assert!(exists(dir.path(), &name('a')));
    }

    #[test]
    fn a_time_in_the_future_is_fresh_up_to_a_day_and_idle_beyond() {
        let dir = TempDir::new().unwrap();
        let now = SystemTime::now();
        put(dir.path(), &name('a'), now + DAY / 2);
        put(dir.path(), &name('b'), now + DAY * 2);
        assert_eq!(sweep(dir.path(), &LIMITS, now).unwrap(), 1);
        assert!(exists(dir.path(), &name('a')));
        assert!(!exists(dir.path(), &name('b')));
    }

    #[test]
    fn the_listing_stops_at_the_limit() {
        let dir = TempDir::new().unwrap();
        let now = SystemTime::now();
        let limits = SweepLimits {
            max_entries: 100,
            keep_entries: 90,
            ..small()
        };
        for i in 0..15 {
            put(dir.path(), &format!("{i:064x}.kwf"), now - DAY);
        }
        assert_eq!(sweep(dir.path(), &limits, now).unwrap(), 10);
        assert_eq!(files(dir.path()), 15);
    }

    #[test]
    fn the_kept_count_is_the_entries_left() {
        let dir = TempDir::new().unwrap();
        let now = SystemTime::now();
        put(dir.path(), &name('a'), now - 200 * DAY);
        put(dir.path(), &name('b'), now - DAY);
        put(dir.path(), &name('c'), now - DAY);
        put(dir.path(), ".kanaru-tmpOLD", now - DAY);
        put(dir.path(), "notes.txt", now - DAY);
        let kept = sweep(dir.path(), &LIMITS, now).unwrap();
        let left = fs::read_dir(dir.path())
            .unwrap()
            .filter(|e| {
                let n = e.as_ref().unwrap().file_name().into_string().unwrap();
                kind_of(&n) == Some(Kind::Entry)
            })
            .count();
        assert_eq!((kept, left), (2, 2));
    }

    #[test]
    fn a_file_changed_after_the_listing_is_kept() {
        let dir = TempDir::new().unwrap();
        let now = SystemTime::now();
        put(dir.path(), &name('a'), now - 200 * DAY);
        let items = collect(dir.path(), 10).unwrap();
        // Used (touched) after the listing.
        put(dir.path(), &name('a'), now);
        assert!(!remove_if_unchanged(dir.path(), &items[0]));
        assert!(exists(dir.path(), &name('a')));
    }

    // --- trigger rules ---

    fn claimed(limits: &SweepLimits, now: Instant) -> DirState {
        let mut state = DirState::new(limits);
        assert_eq!(claim_rule(&mut state, limits, now), Some(0));
        state
    }

    #[test]
    fn the_first_claim_wins_and_none_follows_while_it_runs() {
        let now = Instant::now();
        let mut state = claimed(&LIMITS, now);
        assert_eq!(claim_rule(&mut state, &LIMITS, now + DAY * 5), None);
    }

    #[test]
    fn after_a_sweep_only_a_day_or_the_threshold_wins_again() {
        let limits = small();
        let now = Instant::now();
        let mut state = claimed(&limits, now);
        end_rule(&mut state, &limits, Some(2), 0, now);
        assert_eq!((state.estimate, state.threshold), (2, 3));
        assert_eq!(claim_rule(&mut state, &limits, now), None);
        let almost = now + DAY - Duration::from_secs(1);
        assert_eq!(claim_rule(&mut state, &limits, almost), None);
        assert_eq!(claim_rule(&mut state, &limits, now + DAY), Some(2));

        let mut state = claimed(&limits, now);
        end_rule(&mut state, &limits, Some(2), 0, now);
        state.estimate += 1;
        assert_eq!(claim_rule(&mut state, &limits, now), None, "at threshold");
        state.estimate += 1;
        assert_eq!(claim_rule(&mut state, &limits, now), Some(4));
    }

    #[test]
    fn writes_during_a_sweep_are_added_to_what_it_kept() {
        let now = Instant::now();
        let mut state = claimed(&LIMITS, now);
        state.estimate += 5;
        end_rule(&mut state, &LIMITS, Some(10), 0, now);
        assert_eq!(state.estimate, 15);
    }

    #[test]
    fn failed_deletes_move_the_threshold_above_what_was_kept() {
        let now = Instant::now();
        let mut state = claimed(&LIMITS, now);
        end_rule(&mut state, &LIMITS, Some(25_000), 0, now);
        assert_eq!(state.threshold, 27_000);
        state.estimate += 2_000;
        assert_eq!(claim_rule(&mut state, &LIMITS, now), None);
    }

    #[test]
    fn a_folder_kept_under_the_cap_is_swept_again_past_the_cap() {
        let now = Instant::now();
        let mut state = claimed(&LIMITS, now);
        end_rule(&mut state, &LIMITS, Some(19_000), 0, now);
        assert_eq!(state.threshold, 20_000);
        state.estimate += 1_000;
        assert_eq!(claim_rule(&mut state, &LIMITS, now), None, "at the cap");
        state.estimate += 1;
        assert_eq!(claim_rule(&mut state, &LIMITS, now), Some(20_001));
    }

    #[test]
    fn a_failed_sweep_keeps_the_estimate_and_waits_a_day() {
        let limits = small();
        let now = Instant::now();
        let mut state = claimed(&limits, now);
        state.estimate = 50;
        end_rule(&mut state, &limits, None, 0, now);
        assert_eq!(state.estimate, 50);
        assert_eq!(claim_rule(&mut state, &limits, now + DAY / 2), None);
        assert_eq!(claim_rule(&mut state, &limits, now + DAY), Some(50));
    }

    #[test]
    fn dropping_an_unfinished_ticket_lets_the_next_claim_win() {
        let dir = TempDir::new().unwrap();
        let ticket = claim(dir.path()).expect("first claim");
        assert!(claim(dir.path()).is_none(), "one at a time");
        drop(ticket);
        let again = claim(dir.path());
        assert!(again.is_some());
    }

    #[test]
    fn a_finished_ticket_leaves_the_folder_swept() {
        let dir = TempDir::new().unwrap();
        let old = SystemTime::now() - 100 * DAY;
        put(dir.path(), &name('a'), old);
        claim(dir.path()).unwrap().run();
        assert!(!exists(dir.path(), &name('a')));
        assert!(claim(dir.path()).is_none(), "swept less than a day ago");
    }
}
