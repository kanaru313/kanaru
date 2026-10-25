//! Waveform jobs: the cache, cancelling, stalls and the thread cap. Decodes
//! are held at a known point with a gate instead of racing on timing.

mod common;

use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::{Duration, Instant};

use common::{sine_samples, wav_bytes};
use rust_lib_kanaru::api::waveform::{
    begin_waveform_job, cancel_waveform, TrackWaveform, WaveformStatus,
};
use rust_lib_kanaru::waveform_control::{decode_count, install_decode_gate};
use rust_lib_kanaru::waveform_job::{load, JobEnv};
use tempfile::TempDir;

/// A 4 s WAV, long enough for several packets.
fn sine_wav(dir: &TempDir, name: &str) -> PathBuf {
    let path = dir.path().join(name);
    fs::write(&path, wav_bytes(8000, 1, &sine_samples(32_000, 1), None)).unwrap();
    path
}

/// A WAV at 4 Hz: a stream that fails the limits, the same way every time.
fn broken_wav(dir: &TempDir) -> PathBuf {
    let path = dir.path().join("broken.wav");
    fs::write(&path, wav_bytes(4, 1, &sine_samples(2000, 1), None)).unwrap();
    path
}

fn env() -> JobEnv {
    JobEnv::new(Duration::from_secs(10), 8)
}

fn load_cached(env: &JobEnv, path: &Path, cache: &Path) -> TrackWaveform {
    load(
        env,
        &path.to_string_lossy(),
        &cache.to_string_lossy(),
        begin_waveform_job(),
    )
}

fn cache_files(cache: &Path) -> Vec<PathBuf> {
    match fs::read_dir(cache) {
        Ok(entries) => entries
            .map(|e| e.unwrap().path())
            .filter(|p| p.extension().is_some_and(|e| e == "kwf"))
            .collect(),
        Err(_) => Vec::new(),
    }
}

fn decodes(cache: &Path) -> usize {
    decode_count(&cache.to_string_lossy())
}

fn wait_until(what: &str, mut done: impl FnMut() -> bool) {
    let start = Instant::now();
    while !done() {
        assert!(
            start.elapsed() < Duration::from_secs(5),
            "timed out: {what}"
        );
        std::thread::sleep(Duration::from_millis(5));
    }
}

#[test]
fn the_second_load_comes_from_the_cache() {
    let (files, cache) = (TempDir::new().unwrap(), TempDir::new().unwrap());
    let wav = sine_wav(&files, "a.wav");
    let first = load_cached(&env(), &wav, cache.path());
    assert_eq!(first.status, WaveformStatus::Ready);
    assert_eq!(cache_files(cache.path()).len(), 1);
    let second = load_cached(&env(), &wav, cache.path());
    assert_eq!(second, first);
    assert_eq!(decodes(cache.path()), 1);
}

#[test]
fn a_changed_file_is_decoded_again() {
    let (files, cache) = (TempDir::new().unwrap(), TempDir::new().unwrap());
    let wav = sine_wav(&files, "a.wav");
    load_cached(&env(), &wav, cache.path());
    let file = fs::File::options().write(true).open(&wav).unwrap();
    file.set_modified(std::time::SystemTime::now() + Duration::from_secs(60))
        .unwrap();
    assert_eq!(
        load_cached(&env(), &wav, cache.path()).status,
        WaveformStatus::Ready
    );
    assert_eq!(decodes(cache.path()), 2);
}

#[test]
fn a_damaged_cache_file_is_decoded_and_overwritten() {
    let (files, cache) = (TempDir::new().unwrap(), TempDir::new().unwrap());
    let wav = sine_wav(&files, "a.wav");
    let good = load_cached(&env(), &wav, cache.path());
    let entry = cache_files(cache.path()).remove(0);
    let valid = fs::read(&entry).unwrap();
    let damages: [(&str, Vec<u8>); 3] = [
        ("corrupt header", [b"JUNK".as_slice(), &valid[4..]].concat()),
        ("version 0", [&valid[..4], &[0], &valid[5..]].concat()),
        ("truncated", valid[..valid.len() - 5].to_vec()),
    ];
    for (n, (what, bytes)) in damages.into_iter().enumerate() {
        fs::write(&entry, bytes).unwrap();
        assert_eq!(load_cached(&env(), &wav, cache.path()), good, "{what}");
        assert_eq!(decodes(cache.path()), n + 2, "{what}");
        assert_eq!(fs::read(&entry).unwrap(), valid, "{what} overwritten");
    }
}

#[test]
fn a_cache_folder_that_cannot_be_written_still_gives_the_result() {
    if unsafe { libc::geteuid() } == 0 {
        return; // root writes anywhere
    }
    let (files, cache) = (TempDir::new().unwrap(), TempDir::new().unwrap());
    let wav = sine_wav(&files, "a.wav");
    fs::set_permissions(cache.path(), fs::Permissions::from_mode(0o555)).unwrap();
    let waveform = load_cached(&env(), &wav, cache.path());
    fs::set_permissions(cache.path(), fs::Permissions::from_mode(0o755)).unwrap();
    assert_eq!(waveform.status, WaveformStatus::Ready);
    assert!(cache_files(cache.path()).is_empty());
}

#[test]
fn a_failure_beyond_the_limits_is_remembered() {
    let (files, cache) = (TempDir::new().unwrap(), TempDir::new().unwrap());
    let wav = broken_wav(&files);
    assert_eq!(
        load_cached(&env(), &wav, cache.path()).status,
        WaveformStatus::Failed
    );
    assert_eq!(cache_files(cache.path()).len(), 1);
    assert_eq!(
        load_cached(&env(), &wav, cache.path()).status,
        WaveformStatus::Failed
    );
    assert_eq!(decodes(cache.path()), 1);
}

#[test]
fn a_file_that_cannot_be_read_or_decoded_leaves_no_entry() {
    let (files, cache) = (TempDir::new().unwrap(), TempDir::new().unwrap());
    let missing = files.path().join("gone.wav");
    assert_eq!(
        load_cached(&env(), &missing, cache.path()).status,
        WaveformStatus::Busy
    );
    let opus = common::fixture("sample.opus");
    assert_eq!(
        load_cached(&env(), &opus, cache.path()).status,
        WaveformStatus::Unsupported
    );
    assert!(cache_files(cache.path()).is_empty());
}

#[test]
fn a_job_cancelled_before_it_starts_does_no_work() {
    let (files, cache) = (TempDir::new().unwrap(), TempDir::new().unwrap());
    let wav = sine_wav(&files, "a.wav");
    let job = begin_waveform_job();
    cancel_waveform(job);
    let result = load(
        &env(),
        &wav.to_string_lossy(),
        &cache.path().to_string_lossy(),
        job,
    );
    assert_eq!(result.status, WaveformStatus::Cancelled);
    assert_eq!(decodes(cache.path()), 0);
    cancel_waveform(job); // finished id: nothing happens
}

#[test]
fn cancelling_a_running_job_returns_promptly() {
    let (files, cache) = (TempDir::new().unwrap(), TempDir::new().unwrap());
    let wav = sine_wav(&files, "a.wav");
    let gate = install_decode_gate(&wav, 1);
    let (env, job) = (Arc::new(env()), begin_waveform_job());
    let worker = {
        let (env, wav, cache) = (env.clone(), wav.clone(), cache.path().to_path_buf());
        std::thread::spawn(move || {
            load(&env, &wav.to_string_lossy(), &cache.to_string_lossy(), job)
        })
    };
    assert!(
        gate.gate.wait_reached(Duration::from_secs(5)),
        "decode started"
    );
    let start = Instant::now();
    cancel_waveform(job);
    let result = worker.join().unwrap();
    assert!(
        start.elapsed() < Duration::from_secs(1),
        "{:?}",
        start.elapsed()
    );
    assert_eq!(result.status, WaveformStatus::Cancelled);
    gate.gate.release();
    wait_until("job thread ends", || env.live_threads() == 0);
    assert!(
        cache_files(cache.path()).is_empty(),
        "a cancelled decode writes nothing"
    );
}

#[test]
fn a_stalled_job_is_busy_and_not_remembered() {
    let (files, cache) = (TempDir::new().unwrap(), TempDir::new().unwrap());
    let wav = sine_wav(&files, "a.wav");
    let gate = install_decode_gate(&wav, 1);
    let env = JobEnv::new(Duration::from_millis(500), 8);
    let start = Instant::now();
    let result = load_cached(&env, &wav, cache.path());
    assert_eq!(result.status, WaveformStatus::Busy);
    assert!(start.elapsed() >= Duration::from_millis(500));
    assert!(
        start.elapsed() < Duration::from_secs(3),
        "{:?}",
        start.elapsed()
    );
    assert!(
        cache_files(cache.path()).is_empty(),
        "a stall writes no entry"
    );
    assert_eq!(env.live_threads(), 1, "the stuck thread is still there");

    gate.gate.release();
    wait_until("stuck thread ends", || env.live_threads() == 0);
    assert_eq!(
        load_cached(&env, &wav, cache.path()).status,
        WaveformStatus::Ready
    );
}

#[test]
fn a_third_job_is_busy_while_two_threads_are_stuck() {
    let (files, cache) = (TempDir::new().unwrap(), TempDir::new().unwrap());
    let env = Arc::new(JobEnv::new(Duration::from_secs(30), 2));
    let names = ["a.wav", "b.wav", "c.wav"].map(|n| sine_wav(&files, n));
    let gates = [&names[0], &names[1]].map(|p| install_decode_gate(p, 1));
    let workers = [&names[0], &names[1]].map(|wav| {
        let (env, wav, cache) = (env.clone(), wav.clone(), cache.path().to_path_buf());
        let job = begin_waveform_job();
        std::thread::spawn(move || {
            load(&env, &wav.to_string_lossy(), &cache.to_string_lossy(), job)
        })
    });
    for gate in &gates {
        assert!(gate.gate.wait_reached(Duration::from_secs(5)));
    }
    let start = Instant::now();
    let third = load_cached(&env, &names[2], cache.path());
    assert_eq!(third.status, WaveformStatus::Busy);
    assert!(
        start.elapsed() < Duration::from_millis(500),
        "{:?}",
        start.elapsed()
    );
    for gate in &gates {
        gate.gate.release();
    }
    for worker in workers {
        assert_eq!(worker.join().unwrap().status, WaveformStatus::Ready);
    }
}

#[cfg(target_os = "linux")]
#[test]
fn the_decode_thread_runs_at_a_lower_priority() {
    let (files, cache) = (TempDir::new().unwrap(), TempDir::new().unwrap());
    let wav = sine_wav(&files, "a.wav");
    let gate = install_decode_gate(&wav, 1);
    let env = Arc::new(env());
    let worker = {
        let (env, wav, cache) = (env.clone(), wav.clone(), cache.path().to_path_buf());
        let job = begin_waveform_job();
        std::thread::spawn(move || {
            load(&env, &wav.to_string_lossy(), &cache.to_string_lossy(), job)
        })
    };
    assert!(gate.gate.wait_reached(Duration::from_secs(5)));
    let nice = gate.gate.nice_of_held_thread();
    gate.gate.release();
    assert_eq!(worker.join().unwrap().status, WaveformStatus::Ready);
    assert!(nice >= 10, "nice {nice}");
}
