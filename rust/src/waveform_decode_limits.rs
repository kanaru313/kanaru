//! Limits that keep an untrusted audio file from exhausting time or memory
//! while it is decoded for a waveform.

use std::fs::File;
use std::io::{Read, Seek};
use std::path::Path;

use symphonia::core::codecs::audio::AudioCodecParameters;

use crate::waveform_decode::{broken, DecodeOutcome, Failure, Step};
use crate::waveform_levels::LevelAccumulator;

/// Sample rates accepted, in Hz.
const RATES: std::ops::RangeInclusive<u32> = 8_000..=768_000;
/// Channel counts accepted.
const CHANNELS: std::ops::RangeInclusive<usize> = 1..=32;
/// Longest decoded audio accepted, in seconds (24 hours).
const MAX_SECONDS: u64 = 24 * 60 * 60;
/// Packets that fail to decode in a row before the file counts as broken.
const MAX_CONSECUTIVE_ERRORS: u32 = 32;
/// Packets that fail to decode, plus container resets, before the file
/// counts as broken. A chained Ogg album needs one reset per track.
const MAX_TOTAL_ERRORS: u32 = 1000;
/// Extensions of formats symphonia has no demuxer for. Its MP3 reader would
/// otherwise take compressed APE, WavPack or AIFF bytes for a few MP3 frames
/// and draw noise, so these are refused before any probing.
const NO_DEMUXER_EXTENSIONS: [&str; 6] = ["ape", "wv", "dsf", "dff", "aif", "aiff"];
/// The same formats by their first four bytes, for files with a wrong name.
const NO_DEMUXER_MAGIC: [&[u8; 4]; 5] = [b"MAC ", b"wvpk", b"DSD ", b"FRM8", b"FORM"];

/// `Unsupported` for formats symphonia cannot demux, by extension or magic.
/// Leaves the file positioned at its start.
pub(crate) fn refuse_undecodable(path: &Path, file: &mut File) -> Step<()> {
    let by_name = path.extension().and_then(|e| e.to_str()).is_some_and(|e| {
        NO_DEMUXER_EXTENSIONS
            .iter()
            .any(|x| x.eq_ignore_ascii_case(e))
    });
    let mut magic = [0u8; 4];
    let by_magic = file.read_exact(&mut magic).is_ok() && NO_DEMUXER_MAGIC.contains(&&magic);
    file.rewind()
        .map_err(|_| DecodeOutcome::Failed(Failure::Io))?;
    if by_name || by_magic {
        Err(DecodeOutcome::Unsupported)
    } else {
        Ok(())
    }
}

fn check_shape(rate: u32, channels: usize) -> Step<()> {
    if RATES.contains(&rate) && CHANNELS.contains(&channels) {
        Ok(())
    } else {
        Err(broken("sample rate or channels out of range"))
    }
}

/// Checks the shape a container states for a track, before any decoding.
pub(crate) fn check_declared_shape(params: &AudioCodecParameters) -> Step<()> {
    match (params.sample_rate, params.channels.as_ref()) {
        (Some(rate), Some(channels)) => check_shape(rate, channels.count()),
        (Some(rate), None) if !RATES.contains(&rate) => Err(broken("sample rate out of range")),
        _ => Ok(()),
    }
}

/// Counts packets that failed to decode and container resets.
#[derive(Default)]
pub(crate) struct ErrorBudget {
    consecutive: u32,
    total: u32,
}

impl ErrorBudget {
    /// A packet decoded: the run of failures is over.
    pub(crate) fn packet_decoded(&mut self) {
        self.consecutive = 0;
    }

    /// A packet failed to decode and was skipped.
    pub(crate) fn packet_failed(&mut self) -> Step<()> {
        self.consecutive += 1;
        self.total += 1;
        if self.consecutive > MAX_CONSECUTIVE_ERRORS || self.total > MAX_TOTAL_ERRORS {
            return Err(broken("too many undecodable packets"));
        }
        Ok(())
    }

    /// The container asked for new decoders.
    pub(crate) fn reset(&mut self) -> Step<()> {
        self.total += 1;
        if self.total > MAX_TOTAL_ERRORS {
            return Err(broken("too many stream resets"));
        }
        Ok(())
    }
}

/// Rate, channels and levels of the stream being decoded.
pub(crate) struct Streaming {
    shape: Option<(u32, usize)>,
    levels: Option<LevelAccumulator>,
    max_seconds: u64,
}

impl Streaming {
    pub(crate) fn new() -> Self {
        Self {
            shape: None,
            levels: None,
            max_seconds: MAX_SECONDS,
        }
    }

    /// Checks the shape of a decoded buffer against the limits and against
    /// the buffers before it.
    pub(crate) fn accept(&mut self, rate: u32, channels: usize) -> Step<()> {
        match self.shape {
            None => {
                check_shape(rate, channels)?;
                self.shape = Some((rate, channels));
                self.levels = Some(LevelAccumulator::new(rate));
            }
            Some(shape) if shape != (rate, channels) => {
                return Err(broken("sample rate or channels changed"));
            }
            Some(_) => {}
        }
        Ok(())
    }

    /// Adds interleaved samples of an accepted buffer.
    pub(crate) fn push(&mut self, samples: &[f32]) -> Step<()> {
        let (rate, channels) = self.shape.expect("accept ran first");
        let levels = self.levels.as_mut().expect("accept ran first");
        levels.push(samples, channels);
        if levels.frames() > u64::from(rate) * self.max_seconds {
            return Err(broken("longer than 24 hours"));
        }
        Ok(())
    }

    pub(crate) fn finish(self) -> Step<DecodeOutcome> {
        match (self.shape, self.levels) {
            (Some((sample_rate, _)), Some(levels)) if levels.frames() > 0 => {
                let (levels, frames) = levels.finish();
                Ok(DecodeOutcome::Ready {
                    levels,
                    frames,
                    sample_rate,
                })
            }
            _ => Err(broken("no audio decoded")),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn is_broken<T: std::fmt::Debug>(step: Step<T>) -> bool {
        matches!(step, Err(DecodeOutcome::Failed(Failure::Broken(_))))
    }

    #[test]
    fn a_stream_that_changes_shape_is_broken() {
        let mut stream = Streaming::new();
        assert!(stream.accept(44_100, 2).is_ok());
        assert!(stream.accept(44_100, 2).is_ok());
        assert!(is_broken(stream.accept(48_000, 2)));
        assert!(is_broken(stream.accept(44_100, 1)));
    }

    #[test]
    fn the_first_shape_must_be_inside_the_limits() {
        for (rate, channels) in [(4, 1), (200_000_000, 1), (44_100, 0), (44_100, 33)] {
            assert!(is_broken(Streaming::new().accept(rate, channels)));
        }
    }

    #[test]
    fn decoded_audio_past_the_length_cap_is_broken() {
        // A one second cap stands in for the 24 hours.
        let mut stream = Streaming::new();
        stream.max_seconds = 1;
        stream.accept(8_000, 1).unwrap();
        assert!(stream.push(&vec![0.1; 8_000]).is_ok());
        assert!(is_broken(stream.push(&[0.1])));
    }

    #[test]
    fn packet_errors_in_a_row_use_up_the_budget() {
        let mut budget = ErrorBudget::default();
        for _ in 0..MAX_CONSECUTIVE_ERRORS {
            budget.packet_failed().unwrap();
        }
        assert!(is_broken(budget.packet_failed()));
    }

    #[test]
    fn a_good_packet_ends_the_run_but_not_the_total() {
        let mut budget = ErrorBudget::default();
        for _ in 0..MAX_TOTAL_ERRORS {
            budget.packet_failed().unwrap();
            budget.packet_decoded();
        }
        assert!(is_broken(budget.packet_failed()));
    }

    #[test]
    fn resets_share_the_total_budget_with_packet_errors() {
        let mut budget = ErrorBudget::default();
        for _ in 0..MAX_TOTAL_ERRORS - 1 {
            budget.reset().unwrap();
        }
        // A chained album of hundreds of tracks fits.
        budget.packet_failed().unwrap();
        assert!(is_broken(budget.reset()));
    }
}
