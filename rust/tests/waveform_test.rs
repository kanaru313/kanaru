//! Decoding audio files into waveform levels: every fixture format, the
//! limits on untrusted input, and broken files.
//!
//! The AAC fixtures were made with ffmpeg (see `fixtures/README.md`).

mod common;

use std::fs;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

use common::{fixture, mkfifo, mp3_with_id3_padding, sine_samples, wav_bytes};
use rust_lib_kanaru::api::waveform::{begin_waveform_job, TrackWaveform, WaveformStatus};
use rust_lib_kanaru::waveform_control::JobControl;
use rust_lib_kanaru::waveform_decode::{decode_levels, DecodeOutcome};
use rust_lib_kanaru::waveform_job::{load, JobEnv};
use tempfile::TempDir;

/// Loads `path` without a cache, under limits private to this call.
fn load_file(path: &Path) -> TrackWaveform {
    let env = JobEnv::new(Duration::from_secs(10), 8);
    load(&env, &path.to_string_lossy(), "", begin_waveform_job())
}

fn write_wav(dir: &TempDir, name: &str, bytes: Vec<u8>) -> PathBuf {
    let path = dir.path().join(name);
    fs::write(&path, bytes).unwrap();
    path
}

fn assert_ready(waveform: &TrackWaveform, what: &str) {
    assert_eq!(waveform.status, WaveformStatus::Ready, "{what}");
    assert!(!waveform.levels.is_empty(), "{what}");
    assert!(waveform.duration_ms > 0, "{what}");
}

#[test]
fn a_two_second_sine_gives_levels_and_its_duration() {
    let dir = TempDir::new().unwrap();
    let wav = write_wav(
        &dir,
        "sine.wav",
        wav_bytes(8000, 1, &sine_samples(16_000, 1), None),
    );
    let waveform = load_file(&wav);
    assert_eq!(waveform.status, WaveformStatus::Ready);
    assert!(
        waveform.duration_ms.abs_diff(2000) <= 10,
        "{}",
        waveform.duration_ms
    );
    assert_eq!(waveform.levels.len(), 200);
    assert!(waveform.levels.iter().all(|&l| l >= 240));
}

#[test]
fn a_data_chunk_longer_than_the_file_decodes_what_is_there() {
    let dir = TempDir::new().unwrap();
    // Claims 2 s, holds 1 s.
    let wav = write_wav(
        &dir,
        "cut.wav",
        wav_bytes(8000, 1, &sine_samples(8000, 1), Some(32_000)),
    );
    let waveform = load_file(&wav);
    assert_eq!(waveform.status, WaveformStatus::Ready);
    assert!(
        waveform.duration_ms.abs_diff(1000) <= 10,
        "{}",
        waveform.duration_ms
    );
}

#[test]
fn a_header_claiming_more_than_a_day_decodes_the_real_length() {
    let dir = TempDir::new().unwrap();
    // 0x7FFF_FFF0 bytes of 8 kHz mono is about 37 hours.
    let wav = write_wav(
        &dir,
        "long.wav",
        wav_bytes(8000, 1, &sine_samples(8000, 1), Some(0x7FFF_FFF0)),
    );
    let waveform = load_file(&wav);
    assert_eq!(waveform.status, WaveformStatus::Ready);
    assert!(
        waveform.duration_ms.abs_diff(1000) <= 10,
        "{}",
        waveform.duration_ms
    );
}

#[test]
fn a_clip_shorter_than_ten_milliseconds_is_ready_without_levels() {
    let dir = TempDir::new().unwrap();
    let wav = write_wav(
        &dir,
        "tiny.wav",
        wav_bytes(8000, 1, &sine_samples(40, 1), None),
    );
    let waveform = load_file(&wav);
    assert_eq!(waveform.status, WaveformStatus::Ready);
    assert!(waveform.levels.is_empty());
    assert_eq!(waveform.duration_ms, 5);
}

#[test]
fn a_rate_or_channel_count_out_of_range_fails() {
    let dir = TempDir::new().unwrap();
    for (name, rate, channels) in [
        ("slow.wav", 4, 1),
        ("fast.wav", 200_000_000, 1),
        ("many.wav", 8000, 64),
    ] {
        let wav = write_wav(
            &dir,
            name,
            wav_bytes(rate, channels, &sine_samples(2000, channels), None),
        );
        assert_eq!(load_file(&wav).status, WaveformStatus::Failed, "{name}");
    }
}

#[test]
fn every_supported_fixture_gives_levels() {
    for name in [
        "sample.mp3",
        "sample_v23.mp3",
        "sample.flac",
        "sample.ogg",
        "sample.oga",
        "sample.m4a",
        "sample.alac",
        "sample.wav",
        "sample_aac.m4a",
        "sample_96k24.flac",
        "sample_6ch.flac",
        // ALAC in an MP4 container named .mp3: the hint sends the probe to
        // the MP3 reader first.
        "m4a_named.mp3",
    ] {
        assert_ready(&load_file(&fixture(name)), name);
    }
}

#[test]
fn formats_without_a_decoder_are_unsupported() {
    for name in [
        "sample.opus",
        "opus_in_ogg.oga",
        "sample.ape",
        "sample.wv",
        // The AIFF reader is left out of the build to stay in the size budget.
        "sample.aiff",
    ] {
        assert_eq!(
            load_file(&fixture(name)).status,
            WaveformStatus::Unsupported,
            "{name}"
        );
    }
}

/// symphonia 0.6.1 decodes raw ADTS AAC.
#[test]
fn an_adts_aac_stream_decodes() {
    assert_ready(&load_file(&fixture("sample.aac")), "sample.aac");
}

#[test]
fn an_mp3_behind_a_two_megabyte_id3_tag_decodes() {
    let dir = TempDir::new().unwrap();
    let mp3 = write_wav(&dir, "cover.mp3", mp3_with_id3_padding(2 * 1024 * 1024));
    assert_ready(&load_file(&mp3), "2 MiB tag");
}

#[test]
fn a_missing_file_a_folder_and_a_fifo_fail_fast() {
    let dir = TempDir::new().unwrap();
    let fifo = dir.path().join("pipe.flac");
    mkfifo(&fifo);
    for path in [dir.path().join("gone.flac"), dir.path().to_path_buf(), fifo] {
        let start = Instant::now();
        assert_eq!(load_file(&path).status, WaveformStatus::Busy, "{path:?}");
        assert!(start.elapsed() < Duration::from_secs(1), "{path:?}");
    }
}

#[test]
fn a_job_id_that_was_never_begun_is_busy() {
    let env = JobEnv::new(Duration::from_secs(10), 8);
    let path = fixture("sample.flac");
    let waveform = load(&env, &path.to_string_lossy(), "", u32::MAX);
    assert_eq!(waveform.status, WaveformStatus::Busy);
}

#[test]
fn job_ids_only_rise() {
    let (a, b) = (begin_waveform_job(), begin_waveform_job());
    assert!(a >= 1 && b > a);
}

/// Truncated and bit-flipped copies of every fixture never panic or hang.
/// The decoder is called directly: the job wrapper would turn a panic into a
/// plain failure and hide it.
#[test]
fn damaged_files_never_panic_or_hang() {
    let dir = TempDir::new().unwrap();
    let mut seed = 0x2545_F491_4F6C_DD1Du64;
    let mut next = move || {
        seed ^= seed << 13;
        seed ^= seed >> 7;
        seed ^= seed << 17;
        seed
    };
    let mut fixtures: Vec<_> = fs::read_dir(fixture(""))
        .unwrap()
        .map(|entry| entry.unwrap().path())
        .filter(|path| path.extension().is_some_and(|e| e != "md"))
        .collect();
    fixtures.sort();
    assert!(fixtures.len() > 15);
    for original in fixtures {
        let bytes = fs::read(&original).unwrap();
        let name = original.file_name().unwrap().to_string_lossy().into_owned();
        let mut variants: Vec<Vec<u8>> = (1..=10)
            .map(|i| bytes[..bytes.len() * i / 11].to_vec())
            .collect();
        for _ in 0..10 {
            let mut flipped = bytes.clone();
            for _ in 0..50 {
                let at = (next() % flipped.len() as u64) as usize;
                flipped[at] ^= (next() % 255 + 1) as u8;
            }
            variants.push(flipped);
        }
        for (n, variant) in variants.into_iter().enumerate() {
            let path = dir.path().join(format!("{n}-{name}"));
            fs::write(&path, variant).unwrap();
            let start = Instant::now();
            let outcome = catch_unwind(AssertUnwindSafe(|| {
                decode_levels(&path, &JobControl::default())
            }));
            let outcome = outcome.unwrap_or_else(|_| panic!("{name} variant {n} panicked"));
            assert!(
                start.elapsed() < Duration::from_secs(2),
                "{name} variant {n}"
            );
            assert!(
                !matches!(outcome, DecodeOutcome::Cancelled),
                "{name} variant {n}"
            );
        }
    }
}

/// An MP4 sample table claiming billions of entries is refused or read as far
/// as the file goes, without sizing memory from the claim.
#[test]
fn an_mp4_sample_table_claiming_billions_of_entries_is_harmless() {
    let dir = TempDir::new().unwrap();
    for name in ["sample.m4a", "sample_aac.m4a", "sample.alac"] {
        let mut bytes = fs::read(fixture(name)).unwrap();
        let mut patched = 0;
        for table in [&b"stsz"[..], b"stco", b"stts", b"stsc"] {
            if let Some(at) = bytes.windows(4).position(|w| w == table) {
                // size(4) type(4) version+flags(4) [sample size(4)] count(4)
                let count_at = if table == b"stsz" { at + 12 } else { at + 8 };
                bytes[count_at..count_at + 4].copy_from_slice(&u32::MAX.to_be_bytes());
                patched += 1;
            }
        }
        assert!(patched > 0, "{name}");
        let path = write_wav(&dir, name, bytes);
        let start = Instant::now();
        let outcome = decode_levels(&path, &JobControl::default());
        assert!(
            start.elapsed() < Duration::from_secs(2),
            "{name} {outcome:?}"
        );
    }
}
