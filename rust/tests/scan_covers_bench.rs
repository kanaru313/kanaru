//! Times a scan with covers stage by stage on a list of real audio files.
//! Skipped unless `KANARU_BENCH=1`; prints timings, stores no reference
//! numbers.
//!
//! ```text
//! KANARU_BENCH=1 KANARU_BENCH_LIST=files.txt XDG_CACHE_HOME=/tmp/kanaru-scan-covers-cache \
//!   cargo test --release --test scan_covers_bench -- --nocapture
//! ```
//!
//! `KANARU_BENCH_LIST` names a text file with one audio file path per line.
//! `KANARU_BENCH_SECTION` picks `tags`, `serial` or `pool` (default: all);
//! run one per process to read each section's peak memory (`VmHWM`, printed
//! last). `KANARU_BENCH_DUMP` (a path under `/tmp/`) makes `serial` write the
//! `make_jpeg` time of every image, to compare two builds on the same images.
//!
//! Thumbnails go to fresh folders under `$XDG_CACHE_HOME/kanaru-bench`, and
//! `XDG_CACHE_HOME` must be under `/tmp/`: the real cache is never touched,
//! and only folders this test created are removed. Files are read warm (a
//! warm-up pass runs first), so the numbers say nothing about disk speed.
//!
//! * `tags`: `read_tags_batch` on the whole list and on the first batch the
//!   indexer would read (`tagBatchSizeFor`).
//! * `serial`: one thread, one file at a time, the stages of a cover pass
//!   timed apart, with the app's dedup (a key whose thumbnail exists is not
//!   decoded again; a listing and a sidecar image are read once).
//! * `pool`: `read_covers` on the cover pool, 32 files per call with a new
//!   sink per call like the app, cold (empty folder) then warm, and once
//!   with 512 files per call.

use std::cell::RefCell;
use std::collections::{HashMap, HashSet};
use std::io::{self, Cursor, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use image::{ImageDecoder, ImageFormat, ImageReader};
use rust_lib_kanaru::api::tags::{read_tags_batch, CoverStatus};
use rust_lib_kanaru::cover_art::{
    first_source, read_bounded, try_list_images, validate_header, Attempt, ImageListing,
};
use rust_lib_kanaru::cover_batch::read_covers;
use rust_lib_kanaru::cover_cache::{cache_key, CoverSink, TEMP_PREFIX};
use rust_lib_kanaru::cover_thumbnail::make_jpeg;
use rust_lib_kanaru::jpeg_header;
use rust_lib_kanaru::tag_reader::{embedded_pictures_result, read_one, CoverReadError};

/// Same as the app's `coverBatchSize` and the upper bound of its tag batches.
const APP_COVER_CHUNK: usize = 32;
const LARGE_COVER_CHUNK: usize = 512;
/// The stack of a tag or cover pool thread.
const WORKER_STACK_BYTES: usize = 8 * 1024 * 1024;

struct Setup {
    paths: Vec<String>,
    root: PathBuf,
    section: String,
    dump: Option<PathBuf>,
}

/// `None` (with the reason printed) when the benchmark is not asked for.
fn setup() -> Option<Setup> {
    if std::env::var("KANARU_BENCH").as_deref() != Ok("1") {
        eprintln!("skipped: set KANARU_BENCH=1 to run this benchmark");
        return None;
    }
    let Ok(list) = std::env::var("KANARU_BENCH_LIST") else {
        eprintln!("skipped: set KANARU_BENCH_LIST to a file with one audio path per line");
        return None;
    };
    let cache = std::env::var("XDG_CACHE_HOME").unwrap_or_default();
    assert!(
        under_tmp(Path::new(&cache)),
        "XDG_CACHE_HOME must be under /tmp/ (got {cache:?}): the benchmark never uses the real cache"
    );
    let dump = std::env::var("KANARU_BENCH_DUMP").ok().map(PathBuf::from);
    assert!(
        dump.as_deref().is_none_or(under_tmp),
        "KANARU_BENCH_DUMP must be under /tmp/"
    );
    let section = std::env::var("KANARU_BENCH_SECTION").unwrap_or_else(|_| "all".to_owned());
    assert!(
        ["all", "tags", "serial", "pool"].contains(&section.as_str()),
        "KANARU_BENCH_SECTION: all, tags, serial or pool"
    );
    let paths: Vec<String> = std::fs::read_to_string(&list)
        .unwrap_or_else(|e| panic!("cannot read {list}: {e}"))
        .lines()
        .filter(|line| !line.is_empty())
        .map(str::to_owned)
        .collect();
    assert!(!paths.is_empty(), "{list} is empty");
    Some(Setup {
        paths,
        root: Path::new(&cache).join("kanaru-bench"),
        section,
        dump,
    })
}

/// Absolute, under `/tmp/`, and no `..` to climb out of it.
fn under_tmp(path: &Path) -> bool {
    path.starts_with("/tmp/")
        && path
            .components()
            .all(|c| !matches!(c, std::path::Component::ParentDir))
}

/// A new, empty folder for one measurement.
fn fresh_dir(root: &Path, section: &str) -> PathBuf {
    static COUNT: AtomicUsize = AtomicUsize::new(0);
    let dir = root.join(format!(
        "{section}-{}-{}",
        std::process::id(),
        COUNT.fetch_add(1, Ordering::Relaxed)
    ));
    assert!(under_tmp(&dir));
    std::fs::create_dir_all(&dir).unwrap();
    dir
}

/// Removes a folder made by [`fresh_dir`], nothing else.
fn remove_dir(root: &Path, dir: &Path) {
    assert!(under_tmp(dir) && dir.starts_with(root) && dir != root);
    std::fs::remove_dir_all(dir).unwrap();
}

/// User plus system CPU time of the whole process so far, in ms.
fn cpu_ms() -> f64 {
    let mut usage = std::mem::MaybeUninit::<libc::rusage>::zeroed();
    // SAFETY: the pointer is valid for one `rusage`, which getrusage fills.
    let status = unsafe { libc::getrusage(libc::RUSAGE_SELF, usage.as_mut_ptr()) };
    assert_eq!(status, 0, "getrusage failed");
    // SAFETY: initialised by the successful call above.
    let usage = unsafe { usage.assume_init() };
    let ms = |t: libc::timeval| t.tv_sec as f64 * 1000.0 + t.tv_usec as f64 / 1000.0;
    ms(usage.ru_utime) + ms(usage.ru_stime)
}

/// Wall and CPU time of a measurement.
struct Clock(Instant, f64);

impl Clock {
    fn start() -> Self {
        Self(Instant::now(), cpu_ms())
    }

    /// (wall ms, cpu ms) since [`start`](Self::start).
    fn stop(&self) -> (f64, f64) {
        (self.0.elapsed().as_secs_f64() * 1000.0, cpu_ms() - self.1)
    }
}

fn ms(d: Duration) -> f64 {
    d.as_secs_f64() * 1000.0
}

/// CPU time of the calling thread. Unlike wall time it does not grow when
/// other processes keep the machine busy, so it is the number to compare.
fn thread_cpu() -> Duration {
    let mut now = libc::timespec {
        tv_sec: 0,
        tv_nsec: 0,
    };
    // SAFETY: the pointer is valid for one `timespec`, which clock_gettime fills.
    let status = unsafe { libc::clock_gettime(libc::CLOCK_THREAD_CPUTIME_ID, &mut now) };
    assert_eq!(status, 0, "clock_gettime failed");
    Duration::new(now.tv_sec as u64, now.tv_nsec as u32)
}

/// Wall and thread CPU time of one stage.
#[derive(Default, Clone, Copy)]
struct Span {
    wall: Duration,
    cpu: Duration,
}

impl std::ops::AddAssign for Span {
    fn add_assign(&mut self, other: Span) {
        self.wall += other.wall;
        self.cpu += other.cpu;
    }
}

impl std::ops::Add for Span {
    type Output = Span;
    fn add(mut self, other: Span) -> Span {
        self += other;
        self
    }
}

/// A point in time to measure a [`Span`] from.
struct Stamp(Instant, Duration);

impl Stamp {
    fn now() -> Self {
        Self(Instant::now(), thread_cpu())
    }

    fn elapsed(&self) -> Span {
        Span {
            wall: self.0.elapsed(),
            cpu: thread_cpu().saturating_sub(self.1),
        }
    }
}

/// One markdown table row: `| section | name | wall | cpu | ms/file | ms/thumb | % |`.
fn row(section: &str, name: &str, wall: f64, cpu: f64, files: usize, made: usize, pct: f64) {
    let per = |total: f64, n: usize| {
        if n == 0 {
            "-".to_owned()
        } else {
            format!("{:.3}", total / n as f64)
        }
    };
    println!(
        "| {section} | {name} | {wall:.1} | {cpu:.1} | {} | {} | {pct:.1} |",
        per(wall, files),
        per(wall, made)
    );
}

fn count(name: &str, fields: &[(&str, usize)]) {
    let fields: Vec<String> = fields.iter().map(|(k, v)| format!("{k}={v}")).collect();
    println!("COUNT {name} {}", fields.join(" "));
}

/// Peak resident memory of the process so far, in KiB.
fn vm_hwm_kib() -> u64 {
    let status = std::fs::read_to_string("/proc/self/status").unwrap();
    let line = status.lines().find(|l| l.starts_with("VmHWM:")).unwrap();
    line.split_whitespace().nth(1).unwrap().parse().unwrap()
}

#[cfg(target_os = "linux")]
#[test]
fn scan_covers_stages() {
    let Some(setup) = setup() else { return };
    println!("| section | name | wall ms | cpu ms | ms/file | ms/thumbnail | % |");
    println!("|---|---|---|---|---|---|---|");
    println!("COUNT list files={}", setup.paths.len());

    // Warm the page cache so no section pays for the first read.
    let warm = Clock::start();
    for path in &setup.paths {
        let _ = read_one(path);
    }
    let (wall, cpu) = warm.stop();
    row("warmup", "read_one all", wall, cpu, setup.paths.len(), 0, 100.0);

    let want = |name: &str| setup.section == "all" || setup.section == name;
    if want("tags") {
        tags_section(&setup.paths);
    }
    if want("serial") {
        let (paths, root, dump) = (setup.paths.clone(), setup.root.clone(), setup.dump.clone());
        std::thread::Builder::new()
            .name("bench-serial".to_owned())
            .stack_size(WORKER_STACK_BYTES)
            .spawn(move || serial_section(&paths, &root, dump.as_deref()))
            .unwrap()
            .join()
            .unwrap();
    }
    if want("pool") {
        pool_section(&setup.paths, &setup.root);
    }
    println!("VMHWM kib={}", vm_hwm_kib());
}

// ---------------------------------------------------------------- tags

/// `read_tags_batch` on the first batch the indexer would read, then on all.
fn tags_section(paths: &[String]) {
    // tagBatchSizeFor: ceil(total / 20) clamped to 32..=512 (and to the list).
    let first = paths.len().div_ceil(20).clamp(32, 512).min(paths.len());
    for (name, slice) in [("first batch", &paths[..first]), ("all", paths)] {
        let clock = Clock::start();
        let tags = read_tags_batch(slice.to_vec());
        let (wall, cpu) = clock.stop();
        assert_eq!(tags.len(), slice.len());
        let failed = tags.iter().filter(|t| t.error.is_some()).count();
        row("tags", &format!("{name} ({})", slice.len()), wall, cpu, slice.len(), 0, 100.0);
        count(&format!("tags {name}"), &[("files", slice.len()), ("errors", failed)]);
    }
}

// -------------------------------------------------------------- serial

#[derive(Default)]
struct Buckets {
    tags: Span,
    tags_and_pictures: Span,
    sidecar_io: Span,
    hash: Span,
    make: Span,
    write: Span,
}

#[derive(Default)]
struct Counts {
    files: usize,
    with_pictures: usize,
    pictures: usize,
    picture_bytes: usize,
    found_embedded: usize,
    found_sidecar: usize,
    none: usize,
    failed: usize,
    already_cached: usize,
    made: usize,
    refused: usize,
    jpeg: usize,
    png: usize,
    webp: usize,
    side_up_to_512: usize,
    side_513_to_1024: usize,
    side_over_1024: usize,
    jpeg_progressive: usize,
    jpeg_exif_rotated: usize,
    webp_exif_rotated: usize,
}

#[derive(Default)]
struct Inner {
    b: Buckets,
    c: Counts,
    /// Keys whose thumbnail was written.
    written: HashSet<String>,
    /// Keys already counted in the size and format statistics.
    classified: HashSet<String>,
    listings: HashMap<PathBuf, Arc<ImageListing>>,
    sidecars: HashMap<PathBuf, Option<String>>,
    /// (key, original bytes, make_jpeg ns) per image tried.
    makes: Vec<(String, usize, u128)>,
}

struct Serial {
    dir: PathBuf,
    inner: RefCell<Inner>,
}

impl Serial {
    /// The cache key of `bytes` (writing the thumbnail first when none is
    /// cached): the app's `CoverSink::store`, with each step timed.
    /// `Ok(None)` when the image is not usable.
    fn store(&self, bytes: &[u8]) -> io::Result<Option<String>> {
        let clock = Stamp::now();
        let format = validate_header(bytes);
        let key = format.map(|_| cache_key(bytes));
        let cached = key.as_ref().is_some_and(|k| {
            std::fs::metadata(self.dir.join(k)).is_ok_and(|m| m.is_file() && m.len() > 0)
        });
        self.inner.borrow_mut().b.hash += clock.elapsed();
        let (Some(format), Some(key)) = (format, key) else {
            return Ok(None);
        };
        if cached {
            self.inner.borrow_mut().c.already_cached += 1;
            return Ok(Some(key));
        }
        {
            let mut inner = self.inner.borrow_mut();
            if inner.classified.insert(key.clone()) {
                classify(&mut inner.c, bytes, format);
            }
        }
        let clock = Stamp::now();
        let jpeg = make_jpeg(bytes, format);
        let spent = clock.elapsed();
        {
            let mut inner = self.inner.borrow_mut();
            inner.b.make += spent;
            inner
                .makes
                .push((key.clone(), bytes.len(), spent.cpu.as_nanos()));
        }
        let Some(jpeg) = jpeg else {
            self.inner.borrow_mut().c.refused += 1;
            return Ok(None);
        };
        let clock = Stamp::now();
        write_atomic(&self.dir.join(&key), &jpeg)?;
        let mut inner = self.inner.borrow_mut();
        inner.b.write += clock.elapsed();
        inner.c.made += 1;
        inner.written.insert(key.clone());
        Ok(Some(key))
    }

    fn listing(&self, dir: &Path) -> io::Result<Arc<ImageListing>> {
        if let Some(found) = self.inner.borrow().listings.get(dir) {
            return Ok(Arc::clone(found));
        }
        let clock = Stamp::now();
        let listed = Arc::new(try_list_images(dir)?);
        let mut inner = self.inner.borrow_mut();
        inner.b.sidecar_io += clock.elapsed();
        inner.listings.insert(dir.to_owned(), Arc::clone(&listed));
        Ok(listed)
    }

    fn sidecar(&self, path: &Path) -> io::Result<Option<String>> {
        if let Some(known) = self.inner.borrow().sidecars.get(path) {
            return Ok(known.clone());
        }
        let clock = Stamp::now();
        let bytes = read_bounded(path)?;
        self.inner.borrow_mut().b.sidecar_io += clock.elapsed();
        let key = match bytes {
            Some(bytes) => self.store(&bytes)?,
            None => None,
        };
        self.inner
            .borrow_mut()
            .sidecars
            .insert(path.to_owned(), key.clone());
        Ok(key)
    }
}

/// Same as the app's `write_atomic`: a temp file in the folder, then a rename.
fn write_atomic(target: &Path, data: &[u8]) -> io::Result<()> {
    let shard = target.parent().unwrap();
    std::fs::create_dir_all(shard)?;
    let mut temp = tempfile::Builder::new()
        .prefix(TEMP_PREFIX)
        .tempfile_in(shard)?;
    temp.write_all(data)?;
    temp.persist(target).map_err(|e| e.error)?;
    Ok(())
}

/// Format, size class, progressive and EXIF orientation of an image about to
/// be decoded. Statistics only: the thumbnail code does its own parsing.
fn classify(c: &mut Counts, bytes: &[u8], format: ImageFormat) {
    let side = match format {
        ImageFormat::Jpeg => {
            c.jpeg += 1;
            jpeg_header::parse(bytes).map(|h| {
                c.jpeg_progressive += usize::from(h.progressive);
                c.jpeg_exif_rotated += usize::from(h.orientation > 1);
                u32::from(h.width.max(h.height))
            })
        }
        ImageFormat::WebP => {
            c.webp += 1;
            let mut decoder = ImageReader::with_format(Cursor::new(bytes), format)
                .into_decoder()
                .ok();
            if let Some(orientation) = decoder.as_mut().and_then(|d| d.orientation().ok()) {
                let upright = orientation == image::metadata::Orientation::NoTransforms;
                c.webp_exif_rotated += usize::from(!upright);
            }
            decoder.map(|d| d.dimensions().0.max(d.dimensions().1))
        }
        _ => {
            c.png += 1;
            ImageReader::with_format(Cursor::new(bytes), format)
                .into_dimensions()
                .ok()
                .map(|(w, h)| w.max(h))
        }
    };
    match side {
        Some(..=512) => c.side_up_to_512 += 1,
        Some(513..=1024) => c.side_513_to_1024 += 1,
        Some(_) => c.side_over_1024 += 1,
        None => {}
    }
}

/// A cover pass on one thread, stage by stage. Runs on a thread with the
/// stack of the pool threads, since lofty recurses on nested containers.
fn serial_section(paths: &[String], root: &Path, dump: Option<&Path>) {
    let dir = fresh_dir(root, "serial");
    let serial = Serial {
        dir: dir.clone(),
        inner: RefCell::default(),
    };
    let clock = Clock::start();
    for path in paths {
        serial.inner.borrow_mut().c.files += 1;
        let start = Stamp::now();
        let _ = read_one(path);
        serial.inner.borrow_mut().b.tags += start.elapsed();
        let start = Stamp::now();
        let pictures = embedded_pictures_result(path);
        serial.inner.borrow_mut().b.tags_and_pictures += start.elapsed();
        let pictures = match pictures {
            Ok(pictures) => pictures,
            Err(CoverReadError::Transient) => {
                serial.inner.borrow_mut().c.failed += 1;
                continue;
            }
            Err(CoverReadError::Permanent) => Vec::new(),
        };
        {
            let mut inner = serial.inner.borrow_mut();
            inner.c.with_pictures += usize::from(!pictures.is_empty());
            inner.c.pictures += pictures.len();
            inner.c.picture_bytes += pictures.iter().map(Vec::len).sum::<usize>();
        }
        // The app's lookup order and dedup, through the same `first_source`.
        let found = first_source(
            Path::new(path),
            pictures,
            |dir| serial.listing(dir).map_err(|_| None),
            |bytes| match serial.store(&bytes) {
                Ok(Some(key)) => {
                    serial.inner.borrow_mut().c.found_embedded += 1;
                    Attempt::Take(Some(key))
                }
                Ok(None) => Attempt::Next,
                Err(_) => Attempt::Take(None),
            },
            |sidecar| match serial.sidecar(sidecar) {
                Ok(Some(key)) => {
                    serial.inner.borrow_mut().c.found_sidecar += 1;
                    Attempt::Take(Some(key))
                }
                Ok(None) => Attempt::Next,
                Err(_) => Attempt::Take(None),
            },
        );
        let mut inner = serial.inner.borrow_mut();
        match found {
            None => inner.c.none += 1,
            Some(None) => inner.c.failed += 1,
            Some(Some(_)) => {}
        }
    }
    let (wall, cpu) = clock.stop();
    let inner = serial.inner.into_inner();
    let (b, c) = (&inner.b, &inner.c);
    let made = c.made;
    // What the app's cover pass does per file: no separate tag read.
    // Buckets show wall and the thread's CPU time; the percentages are of CPU.
    let pass = b.tags_and_pictures + b.sidecar_io + b.hash + b.make + b.write;
    let pct = |d: Span| 100.0 * d.cpu.as_secs_f64() / pass.cpu.as_secs_f64();
    row("serial", "whole loop (incl. tags; cpu of the whole process)", wall, cpu, c.files, made, 100.0 * cpu / ms(pass.cpu));
    row("serial", "cover pass (sum of buckets, no tags)", ms(pass.wall), ms(pass.cpu), c.files, made, 100.0);
    let pictures_load = Span {
        wall: b.tags_and_pictures.wall.saturating_sub(b.tags.wall),
        cpu: b.tags_and_pictures.cpu.saturating_sub(b.tags.cpu),
    };
    for (name, d) in [
        ("tags", b.tags),
        ("tags+pictures", b.tags_and_pictures),
        ("pictures load (tags+pictures - tags)", pictures_load),
        ("sidecar io", b.sidecar_io),
        ("hash (header check, blake3, exists check)", b.hash),
        ("make_jpeg (decode+resize+encode)", b.make),
        ("write", b.write),
    ] {
        row("serial", name, ms(d.wall), ms(d.cpu), c.files, made, pct(d));
    }
    count(
        "serial files",
        &[
            ("files", c.files),
            ("with_pictures", c.with_pictures),
            ("pictures", c.pictures),
            ("picture_bytes", c.picture_bytes),
            ("found_embedded", c.found_embedded),
            ("found_sidecar", c.found_sidecar),
            ("none", c.none),
            ("failed", c.failed),
        ],
    );
    count(
        "serial thumbnails",
        &[
            ("unique_keys", inner.written.len()),
            ("made", c.made),
            ("already_cached_hits", c.already_cached),
            ("refused_or_corrupt", c.refused),
            ("jpeg", c.jpeg),
            ("png", c.png),
            ("webp", c.webp),
            ("side_le_512", c.side_up_to_512),
            ("side_513_1024", c.side_513_to_1024),
            ("side_gt_1024", c.side_over_1024),
            ("jpeg_progressive", c.jpeg_progressive),
            ("jpeg_exif_rotated", c.jpeg_exif_rotated),
            ("webp_exif_rotated", c.webp_exif_rotated),
        ],
    );
    if let Some(dump) = dump {
        let lines: Vec<String> = inner
            .makes
            .iter()
            .map(|(key, size, ns)| format!("{key}\t{size}\t{ns}"))
            .collect();
        std::fs::write(dump, lines.join("\n")).unwrap();
    }
    remove_dir(root, &dir);
}

// ---------------------------------------------------------------- pool

/// What one pass of `read_covers` calls over the list gave.
struct PoolRun {
    made: usize,
    found: usize,
    none: usize,
    failed: usize,
    keys: HashSet<String>,
}

/// `read_covers` over `paths`, `chunk` files per call and a new sink per
/// call, into `dir`.
fn pool_pass(name: &str, paths: &[String], dir: &Path, chunk: usize) -> PoolRun {
    let mut run = PoolRun {
        made: 0,
        found: 0,
        none: 0,
        failed: 0,
        keys: HashSet::new(),
    };
    let clock = Clock::start();
    for part in paths.chunks(chunk) {
        let sink = CoverSink::new(dir);
        let covers = read_covers(part.to_vec(), &sink);
        assert_eq!(covers.len(), part.len());
        run.made += sink.thumbnails_made();
        for cover in covers {
            match cover.status {
                CoverStatus::Found => {
                    run.found += 1;
                    run.keys.extend(cover.cover);
                }
                CoverStatus::None => run.none += 1,
                _ => run.failed += 1,
            }
        }
    }
    let (wall, cpu) = clock.stop();
    row("pool", name, wall, cpu, paths.len(), run.made, 100.0);
    count(
        &format!("pool {name}"),
        &[
            ("thumbnails_made", run.made),
            ("found", run.found),
            ("unique_keys", run.keys.len()),
            ("duplicate_decodes", run.made.saturating_sub(run.keys.len())),
            ("none", run.none),
            ("failed", run.failed),
        ],
    );
    run
}

fn pool_section(paths: &[String], root: &Path) {
    let dir = fresh_dir(root, "pool-chunk32");
    let cold = pool_pass("cold chunk 32", paths, &dir, APP_COVER_CHUNK);
    assert!(cold.made > 0, "the cold pass made no thumbnail: the folder was not empty");
    let warm = pool_pass("warm chunk 32", paths, &dir, APP_COVER_CHUNK);
    assert_eq!(warm.made, 0, "the warm pass made thumbnails");
    remove_dir(root, &dir);

    let dir = fresh_dir(root, "pool-chunk512");
    let large = pool_pass("cold chunk 512", paths, &dir, LARGE_COVER_CHUNK);
    assert!(large.made > 0, "the cold pass made no thumbnail: the folder was not empty");
    remove_dir(root, &dir);
}
