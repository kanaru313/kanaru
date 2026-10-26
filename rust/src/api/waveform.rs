//! Waveform API exposed to Dart: loudness levels of a whole track for the
//! Now Playing seek bar.
//!
//! A load is three calls. [`begin_waveform_job`] hands out a job id,
//! [`load_waveform`] does the work under that id, and [`cancel_waveform`]
//! (from another call) stops it.

use crate::waveform_job;

/// How a [`load_waveform`] call ended.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WaveformStatus {
    /// `levels` and `duration_ms` are set.
    Ready,
    /// No decoder for this container or codec (Opus, APE, WavPack...).
    /// Asking again gives the same answer.
    Unsupported,
    /// The file is broken or beyond the limits. This exact file version
    /// fails the same way again (it is remembered on disk), so callers may
    /// remember it too.
    Failed,
    /// Temporary: the file could not be read now (gone, unreadable mount, not
    /// a regular file), the decode stalled, two waveform threads were already
    /// busy, a thread died, or the job id was not issued by
    /// [`begin_waveform_job`]. Nothing was remembered; callers must not
    /// memoise or cache it, and may ask again later.
    Busy,
    /// The job was cancelled before it finished.
    Cancelled,
}

/// The waveform of one track, from [`load_waveform`]. Flat on purpose so
/// flutter_rust_bridge generates a plain Dart class.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrackWaveform {
    pub status: WaveformStatus,
    /// Up to 1000 loudness levels from 0 to 255, evenly spaced over the
    /// decoded audio. Empty unless `status` is [`WaveformStatus::Ready`], and
    /// also empty for a clip shorter than 10 ms.
    pub levels: Vec<u8>,
    /// Length of the decoded audio in milliseconds (saturating); what the
    /// levels span. 0 unless `status` is [`WaveformStatus::Ready`].
    pub duration_ms: u32,
}

/// Starts a job and returns its id. Ids come from the native side and only
/// rise, so they stay unique across hot restarts of the Dart side.
///
/// Every id that was begun must be passed to [`load_waveform`], even when it
/// was cancelled first: the registry entry is freed there, and an id that
/// never reaches it stays registered for the rest of the run.
#[flutter_rust_bridge::frb(sync)]
pub fn begin_waveform_job() -> u32 {
    waveform_job::begin_job()
}

/// Decodes the audio file at `path` into levels, or reads them from the
/// cache in `cache_dir` (the waveform folder; empty to use no cache), as job
/// `job`. Runs on a low-priority thread of its own and returns when it is
/// done, cancelled, or has made no progress for 10 s (then [`WaveformStatus::Busy`]). Never panics.
///
/// A job that was cancelled before this call returns
/// [`WaveformStatus::Cancelled`] without any work. The job id is spent when
/// this returns.
pub fn load_waveform(path: String, cache_dir: String, job: u32) -> TrackWaveform {
    waveform_job::load_default(&path, &cache_dir, job)
}

/// Stops job `job`: [`load_waveform`] returns [`WaveformStatus::Cancelled`]
/// within about 100 ms. An unknown or finished id does nothing.
#[flutter_rust_bridge::frb(sync)]
pub fn cancel_waveform(job: u32) {
    waveform_job::cancel_job(job);
}
