//! Decodes a whole audio file with symphonia into waveform levels.
//!
//! The file is untrusted: the limits in [`crate::waveform_decode_limits`]
//! bound its sample rate, channels, length and packet errors, and memory does
//! not depend on the length (see [`crate::waveform_levels::LevelAccumulator`]).

use std::fs::{File, Metadata};
use std::io::ErrorKind;
use std::path::Path;

use symphonia::core::codecs::audio::{AudioDecoder, AudioDecoderOptions};
use symphonia::core::errors::Error;
use symphonia::core::formats::probe::Hint;
use symphonia::core::formats::{FormatOptions, FormatReader};
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;

use crate::cover_art::open_nonblocking;
use crate::waveform_control::JobControl;
use crate::waveform_decode_limits::{
    check_declared_shape, refuse_undecodable, ErrorBudget, Streaming,
};

/// Why a decode failed.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Failure {
    /// The file could not be read (gone, unreadable mount, not a regular
    /// file). May pass, so nothing is remembered about it.
    Io,
    /// The stream is malformed or beyond the limits. The same file version
    /// fails the same way, so the failure is remembered.
    Broken(&'static str),
}

/// What decoding one file gave.
#[derive(Debug, PartialEq)]
pub enum DecodeOutcome {
    Ready {
        levels: Vec<u8>,
        frames: u64,
        sample_rate: u32,
    },
    /// No demuxer or decoder for this container or codec.
    Unsupported,
    Failed(Failure),
    Cancelled,
}

pub(crate) type Step<T> = Result<T, DecodeOutcome>;

/// Opens the audio file at `path` without blocking and checks, on the open
/// handle, that it is a regular file (a FIFO would otherwise block the open or
/// the first read). Returns the handle and its metadata.
pub fn open_audio(path: &Path) -> std::io::Result<(File, Metadata)> {
    let file = open_nonblocking(path)?;
    let meta = file.metadata()?;
    if !meta.is_file() {
        return Err(ErrorKind::InvalidInput.into());
    }
    Ok((file, meta))
}

/// Opens and decodes the audio file at `path`; see [`decode_open_file`].
pub fn decode_levels(path: &Path, job: &JobControl) -> DecodeOutcome {
    match open_audio(path) {
        Ok((file, _)) => decode_open_file(path, file, job),
        Err(_) => DecodeOutcome::Failed(Failure::Io),
    }
}

/// Decodes `file`, which was opened from `path` (only its extension is used,
/// as a hint), stopping at the next packet once `job` is cancelled and
/// reporting every packet to it as progress.
pub fn decode_open_file(path: &Path, file: File, job: &JobControl) -> DecodeOutcome {
    match run(path, file, job) {
        Ok(outcome) | Err(outcome) => outcome,
    }
}

fn run(path: &Path, mut file: File, job: &JobControl) -> Step<DecodeOutcome> {
    refuse_undecodable(path, &mut file)?;
    let stream = MediaSourceStream::new(Box::new(file), Default::default());
    let mut hint = Hint::new();
    if let Some(extension) = path.extension().and_then(|e| e.to_str()) {
        hint.with_extension(extension);
    }
    // Memory spent on tags is bounded by the tag sizes in the file.
    let mut format = symphonia::default::get_probe()
        .probe(
            &hint,
            stream,
            FormatOptions::default(),
            MetadataOptions::default(),
        )
        .map_err(|e| failure(&e))?;
    let (mut decoder, mut track_id) = open_decoder(format.as_ref())?;

    let mut state = Streaming::new();
    let mut budget = ErrorBudget::default();
    let mut samples: Vec<f32> = Vec::new();
    loop {
        if job.cancelled() {
            return Ok(DecodeOutcome::Cancelled);
        }
        let packet = match format.next_packet() {
            Ok(Some(packet)) => packet,
            Ok(None) => break,
            Err(Error::ResetRequired) => {
                budget.reset()?;
                (decoder, track_id) = open_decoder(format.as_ref())?;
                continue;
            }
            // A truncated file plays up to where it ends.
            Err(Error::IoError(e)) if e.kind() == ErrorKind::UnexpectedEof => break,
            Err(e) => return Err(failure(&e)),
        };
        job.packet_read();
        if packet.track_id != track_id {
            continue;
        }
        match decoder.decode(&packet) {
            Ok(buffer) => {
                budget.packet_decoded();
                let spec = buffer.spec();
                state.accept(spec.rate(), spec.channels().count())?;
                buffer.copy_to_vec_interleaved(&mut samples);
                state.push(&samples)?;
            }
            Err(Error::DecodeError(_) | Error::IoError(_)) => budget.packet_failed()?,
            Err(e) => return Err(failure(&e)),
        }
    }
    state.finish()
}

/// A decoder for the first audio track that has one, and its id. The shape a
/// container states is checked before any decoding starts; a track that is
/// refused is skipped, and its reason is kept in case no other track works.
fn open_decoder(format: &dyn FormatReader) -> Step<(Box<dyn AudioDecoder>, u32)> {
    let mut refused = DecodeOutcome::Unsupported;
    for track in format.tracks() {
        let Some(params) = track.codec_params.as_ref().and_then(|p| p.audio()) else {
            continue;
        };
        let made = check_declared_shape(params).and_then(|()| {
            symphonia::default::get_codecs()
                .make_audio_decoder(params, &AudioDecoderOptions::default())
                .map_err(|e| failure(&e))
        });
        match made {
            Ok(decoder) => return Ok((decoder, track.id)),
            Err(outcome) if refused == DecodeOutcome::Unsupported => refused = outcome,
            Err(_) => {}
        }
    }
    Err(refused)
}

pub(crate) fn broken(reason: &'static str) -> DecodeOutcome {
    DecodeOutcome::Failed(Failure::Broken(reason))
}

/// Maps a symphonia error to the outcome the cache and the caller act on.
fn failure(error: &Error) -> DecodeOutcome {
    match error {
        Error::Unsupported(_) => DecodeOutcome::Unsupported,
        Error::IoError(e) if e.kind() == ErrorKind::UnexpectedEof => broken("truncated file"),
        Error::IoError(_) => DecodeOutcome::Failed(Failure::Io),
        Error::DecodeError(reason) | Error::LimitError(reason) => broken(reason),
        Error::SeekError(_) | Error::ResetRequired => broken("unexpected stream state"),
        // Error is non-exhaustive; anything new is a stream that cannot be read.
        _ => broken("unreadable stream"),
    }
}
