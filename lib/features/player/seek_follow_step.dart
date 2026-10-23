/// Steps a seek bar may follow playback in. Each divides a second, so the
/// time label, the spoken value and the thumb change on the same frames.
const seekFollowSteps = [
  Duration(milliseconds: 250),
  Duration(milliseconds: 500),
  Duration(seconds: 1),
];

/// The smallest of [seekFollowSteps] at least as long as the time one
/// logical pixel of a [width] wide track stands for, so the thumb moves
/// about a pixel per step. The longest when that is longer still, when
/// [width] is unusable, or when nothing is loaded.
Duration seekFollowStep(Duration duration, double width) {
  final longest = seekFollowSteps.last;
  if (duration <= Duration.zero || !width.isFinite || width <= 0) {
    return longest;
  }
  final millisPerPixel = duration.inMicroseconds / 1000 / width;
  for (final step in seekFollowSteps) {
    if (step.inMilliseconds >= millisPerPixel) return step;
  }
  return longest;
}

/// [position] floored to a multiple of [step] (a negative one becomes zero):
/// what a seek bar shows, never ahead of the audio.
Duration seekShownPosition(Duration position, Duration step) {
  if (position <= Duration.zero) return Duration.zero;
  return Duration(
    microseconds:
        position.inMicroseconds - position.inMicroseconds % step.inMicroseconds,
  );
}
