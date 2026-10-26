//! Reduces decoded audio to at most 1000 loudness levels for the waveform.
//!
//! The length of the track is not known before decoding (VBR MP3 without a
//! header, ADTS), so the accumulator keeps a fixed number of slots and
//! doubles the time each slot covers whenever they are all full. Memory is
//! the same for a 3-second clip and a 24-hour file, and a slot's position is
//! always its time, because the window length is a whole number of frames.

/// Most levels a waveform has.
pub const MAX_LEVELS: usize = 1000;

/// Slots the accumulator keeps; about 128 KB.
const SLOT_COUNT: usize = 8192;

/// Sum of squares and sample count of one window of the track.
#[derive(Clone, Copy, Default)]
struct Slot {
    square_sum: f64,
    samples: u64,
}

impl Slot {
    fn merge(&mut self, other: Slot) {
        self.square_sum += other.square_sum;
        self.samples += other.samples;
    }
}

/// Collects the loudness of a stream of interleaved samples.
pub struct LevelAccumulator {
    slots: Vec<Slot>,
    /// Frames each slot covers now; starts at 10 ms and doubles on a fold.
    window_frames: u64,
    /// Frames the first window had, to tell a clip too short to draw.
    first_window_frames: u64,
    /// Frames pushed so far.
    frames: u64,
}

impl LevelAccumulator {
    /// An accumulator for audio at `sample_rate` Hz (at least 100).
    pub fn new(sample_rate: u32) -> Self {
        Self::with_slots(sample_rate, SLOT_COUNT)
    }

    /// Like [`new`](Self::new) with `slot_count` slots (even, at least 2),
    /// so tests can compare a folded run with an unfolded one.
    fn with_slots(sample_rate: u32, slot_count: usize) -> Self {
        let window = (u64::from(sample_rate) / 100).max(1);
        Self {
            slots: vec![Slot::default(); slot_count],
            window_frames: window,
            first_window_frames: window,
            frames: 0,
        }
    }

    /// Frames pushed so far.
    pub fn frames(&self) -> u64 {
        self.frames
    }

    /// Adds interleaved samples of `channels` channels. A trailing partial
    /// frame is ignored.
    pub fn push(&mut self, interleaved: &[f32], channels: usize) {
        if channels == 0 {
            return;
        }
        let mut rest = interleaved;
        while rest.len() >= channels {
            let index = (self.frames / self.window_frames) as usize;
            if index >= self.slots.len() {
                self.fold();
                continue;
            }
            let room = self.window_frames - self.frames % self.window_frames;
            let frames_here = ((rest.len() / channels) as u64).min(room) as usize;
            let (chunk, remaining) = rest.split_at(frames_here * channels);
            let sum: f64 = chunk.iter().map(|&s| f64::from(s) * f64::from(s)).sum();
            let slot = &mut self.slots[index];
            slot.square_sum += sum;
            slot.samples += chunk.len() as u64;
            self.frames += frames_here as u64;
            rest = remaining;
        }
    }

    /// Merges neighbouring slots pairwise and doubles the window, so the
    /// slots again cover the whole track with room for more.
    fn fold(&mut self) {
        let half = self.slots.len() / 2;
        for i in 0..half {
            let mut merged = self.slots[2 * i];
            merged.merge(self.slots[2 * i + 1]);
            self.slots[i] = merged;
        }
        self.slots[half..].fill(Slot::default());
        self.window_frames *= 2;
    }

    /// The levels and the frames they cover. Empty levels for a clip shorter
    /// than 10 ms. Otherwise `min(1000, used slots)` buckets: loudness is the
    /// RMS of the samples in the bucket, normalised to the loudest bucket
    /// and square-rooted so quiet parts stay visible, then scaled to 0..=255.
    /// Silence gives all zeros.
    pub fn finish(&self) -> (Vec<u8>, u64) {
        if self.frames < self.first_window_frames {
            return (Vec::new(), self.frames);
        }
        let used = self.frames.div_ceil(self.window_frames) as usize;
        let buckets = used.min(MAX_LEVELS);
        let rms: Vec<f64> = (0..buckets)
            .map(|i| {
                let mut total = Slot::default();
                for slot in &self.slots[i * used / buckets..(i + 1) * used / buckets] {
                    total.merge(*slot);
                }
                if total.samples == 0 {
                    0.0
                } else {
                    (total.square_sum / total.samples as f64).sqrt()
                }
            })
            .collect();
        let loudest = rms.iter().copied().fold(0.0, f64::max);
        let levels = rms
            .iter()
            .map(|&r| {
                if loudest <= 0.0 {
                    0
                } else {
                    (255.0 * (r / loudest).sqrt()).round().clamp(0.0, 255.0) as u8
                }
            })
            .collect();
        (levels, self.frames)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const RATE: u32 = 8000;

    /// `seconds` of a sine at `amplitude`, `channels` identical channels.
    fn sine(seconds: f64, amplitude: f32, channels: usize) -> Vec<f32> {
        let frames = (seconds * f64::from(RATE)) as usize;
        (0..frames)
            .flat_map(|n| {
                // 8 samples per period: whole periods in every 10 ms window.
                let v = amplitude * (n as f32 * std::f32::consts::FRAC_PI_4).sin();
                std::iter::repeat_n(v, channels)
            })
            .collect()
    }

    fn levels_of(samples: &[f32], channels: usize) -> Vec<u8> {
        let mut acc = LevelAccumulator::new(RATE);
        acc.push(samples, channels);
        acc.finish().0
    }

    #[test]
    fn a_steady_sine_gives_flat_full_levels() {
        let levels = levels_of(&sine(2.0, 0.5, 1), 1);
        assert_eq!(levels.len(), 200);
        assert!(levels.iter().all(|&l| l.abs_diff(255) <= 3), "{levels:?}");
    }

    #[test]
    fn silence_gives_zero_levels() {
        let levels = levels_of(&vec![0.0; 16_000], 1);
        assert_eq!(levels.len(), 200);
        assert!(levels.iter().all(|&l| l == 0));
    }

    #[test]
    fn a_full_scale_square_gives_full_levels() {
        let square: Vec<f32> = (0..16_000)
            .map(|n| if (n / 20) % 2 == 0 { 1.0 } else { -1.0 })
            .collect();
        assert!(levels_of(&square, 1).iter().all(|&l| l == 255));
    }

    #[test]
    fn a_half_amplitude_half_follows_the_square_root_scale() {
        let mut samples = sine(1.0, 0.25, 1);
        samples.extend(sine(1.0, 0.5, 1));
        let levels = levels_of(&samples, 1);
        let expected = (255.0_f64 * 0.5_f64.sqrt()) as u8;
        assert!(levels[10].abs_diff(expected) <= 4, "{}", levels[10]);
        assert!(levels[190].abs_diff(255) <= 3, "{}", levels[190]);
    }

    #[test]
    fn rms_counts_every_channel() {
        // Stereo with the left channel silent is half the power of a stereo
        // pair with both channels playing.
        let both = sine(1.0, 0.5, 2);
        let left_only: Vec<f32> = both.chunks(2).flat_map(|frame| [frame[0], 0.0]).collect();
        let mut samples = both.clone();
        samples.extend(&left_only);
        let levels = levels_of(&samples, 2);
        let expected = (255.0_f64 * 0.5_f64.sqrt().sqrt()) as u8;
        assert!(levels[10].abs_diff(255) <= 3);
        assert!(levels[110].abs_diff(expected) <= 4, "{}", levels[110]);
    }

    #[test]
    fn a_clip_shorter_than_ten_milliseconds_has_no_levels() {
        let (levels, frames) = {
            let mut acc = LevelAccumulator::new(RATE);
            acc.push(&sine(0.005, 0.5, 1), 1);
            acc.finish()
        };
        assert!(levels.is_empty());
        assert_eq!(frames, 40);
    }

    #[test]
    fn there_are_never_more_than_a_thousand_levels() {
        let levels = levels_of(&sine(20.0, 0.5, 1), 1);
        assert_eq!(levels.len(), MAX_LEVELS);
    }

    #[test]
    fn samples_split_across_pushes_land_in_the_same_slots() {
        let samples = sine(3.0, 0.5, 2);
        let whole = levels_of(&samples, 2);
        let mut acc = LevelAccumulator::new(RATE);
        for piece in samples.chunks(2 * 37) {
            acc.push(piece, 2);
        }
        assert_eq!(acc.finish().0, whole);
    }

    #[test]
    fn folding_keeps_the_slot_count_and_the_shape() {
        // 24 windows of 10 ms into 8 slots fold twice (40 ms windows); the
        // reference has room for every window and never folds.
        let windows = 3 * 8;
        let mut samples = Vec::new();
        for w in 0..windows {
            samples.extend(sine(0.01, 0.1 + 0.8 * (w % 8) as f32 / 8.0, 1));
        }
        let mut small = LevelAccumulator::with_slots(RATE, 8);
        small.push(&samples, 1);
        let mut reference = LevelAccumulator::with_slots(RATE, 64);
        reference.push(&samples, 1);
        assert_eq!(small.slots.len(), 8);
        assert!(small.window_frames > small.first_window_frames);
        assert_eq!(reference.window_frames, reference.first_window_frames);
        let (folded, folded_frames) = small.finish();
        let (plain, plain_frames) = reference.finish();
        assert_eq!(folded_frames, plain_frames);
        assert_eq!(folded.len(), 6);
        assert_eq!(plain.len(), 24);
        // Loudness the levels must have: a window of amplitude `a` has
        // mean square a^2 / 2; a bucket is the root of the mean of its
        // windows' mean squares; then normalise to the loudest and take the
        // square root.
        let amplitude = |w: usize| 0.1 + 0.8 * (w % 8) as f64 / 8.0;
        let expected = |per_bucket: usize, count: usize| -> Vec<f64> {
            let rms: Vec<f64> = (0..count)
                .map(|b| {
                    let squares: f64 = (b * per_bucket..(b + 1) * per_bucket)
                        .map(|w| amplitude(w).powi(2) / 2.0)
                        .sum();
                    (squares / per_bucket as f64).sqrt()
                })
                .collect();
            let loudest = rms.iter().copied().fold(0.0, f64::max);
            rms.iter().map(|r| 255.0 * (r / loudest).sqrt()).collect()
        };
        for (what, got, want) in [
            ("folded", &folded, expected(4, 6)),
            ("plain", &plain, expected(1, 24)),
        ] {
            for (i, (&level, want)) in got.iter().zip(&want).enumerate() {
                assert!(
                    (f64::from(level) - want).abs() <= 2.0,
                    "{what} {i}: {level} vs {want}"
                );
            }
        }
    }

    #[test]
    fn the_full_size_accumulator_folds_past_its_slots() {
        let mut acc = LevelAccumulator::new(RATE);
        // 8192 * 3 windows of 10 ms.
        let window = sine(0.01, 0.5, 1);
        for _ in 0..SLOT_COUNT * 3 {
            acc.push(&window, 1);
        }
        assert_eq!(acc.slots.len(), SLOT_COUNT);
        assert_eq!(acc.window_frames, acc.first_window_frames * 4);
        let (levels, _) = acc.finish();
        assert_eq!(levels.len(), MAX_LEVELS);
        assert!(levels.iter().all(|&l| l.abs_diff(255) <= 3));
    }
}
