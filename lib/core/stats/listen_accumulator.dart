import 'dart:math' as math;

/// Tracks of this length or shorter never count as a listen.
const listenMinTrackLength = Duration(seconds: 30);

/// A listen needs at most this much listening time, however long the track.
const listenThresholdCap = Duration(minutes: 4);

/// The position may run ahead of the clock by this much and still count as
/// played (ticks delivered late, in a burst); more than that is a seek.
const listenSeekSlack = Duration(seconds: 1);

/// Whether [listened] makes a listen of a track that is [length] long
/// (STAT-01): longer than 30 s, and heard for half of it or 4 minutes,
/// whichever is less. An unknown [length] needs the 4 minutes.
bool qualifiesAsListen(Duration listened, Duration? length) {
  if (length != null && length <= listenMinTrackLength) return false;
  final threshold = length == null
      ? listenThresholdCap
      : Duration(
          microseconds: math.min(
            length.inMicroseconds ~/ 2,
            listenThresholdCap.inMicroseconds,
          ),
        );
  return listened >= threshold;
}

/// Listening time of one playthrough. Feed it every player observation.
///
/// Time counts between two consecutive samples that are both playing and
/// whose position moved forward. The position delta is taken as is unless it
/// outruns the monotonic [clock] by more than [listenSeekSlack]; then it was a
/// jump (a seek, whose target the player publishes at once) and only the clock
/// delta counts, the audio that really played before it. A burst of late ticks
/// still counts in full, a stall adds only the position it advanced, and
/// backward moves and pauses add nothing. At most one second per seek is
/// over-counted. The clock is a monotonic elapsed duration supplied by the
/// caller.
class ListenAccumulator {
  ListenAccumulator({
    required Duration position,
    required Duration clock,
    required bool playing,
  }) : _lastPosition = position,
       _lastClock = clock,
       _wasPlaying = playing;

  Duration _lastPosition;
  Duration _lastClock;
  bool _wasPlaying;
  Duration _listened = Duration.zero;

  /// Time listened so far.
  Duration get listened => _listened;

  void sample({
    required Duration position,
    required Duration clock,
    required bool playing,
  }) {
    if (_wasPlaying && playing) {
      final positionDelta = position - _lastPosition;
      if (positionDelta > Duration.zero) {
        final clockDelta = clock - _lastClock;
        _listened += positionDelta <= clockDelta + listenSeekSlack
            ? positionDelta
            : (clockDelta > Duration.zero ? clockDelta : Duration.zero);
      }
    }
    _lastPosition = position;
    _lastClock = clock;
    _wasPlaying = playing;
  }
}
