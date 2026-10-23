/// Tracks of this length or shorter never count as a listen.
const listenMinTrackLength = Duration(seconds: 30);

/// A listen needs at most this much listening time, however long the track,
/// with the default threshold.
const listenThresholdCap = Duration(minutes: 4);

/// The share of a track that counts is never more than its length minus
/// this: the last position the player reports comes a few hundred
/// milliseconds before the end, so "100 %" could never be reached.
const listenEndSlack = Duration(seconds: 1);

/// The position may run ahead of the clock by this much and still count as
/// played (ticks delivered late, in a burst); more than that is a seek.
const listenSeekSlack = Duration(seconds: 1);

/// When a play counts as a listen: after [minutes] of listening or
/// [percent] of the track, whichever comes first (Settings → Advanced).
class ListenThreshold {
  const ListenThreshold({required this.minutes, required this.percent});

  /// The Last.fm / ListenBrainz rule: 4 minutes or half the track.
  static const standard = ListenThreshold(minutes: 4, percent: 50);

  final int minutes;
  final int percent;

  /// Listening time [length] needs: the share, kept within the track minus
  /// [listenEndSlack], or the minutes when that is less. An unknown [length]
  /// needs the minutes.
  Duration requiredFor(Duration? length) {
    final cap = Duration(minutes: minutes);
    if (length == null) return cap;
    final share = Duration(
      microseconds: length.inMicroseconds * percent ~/ 100,
    );
    final reachable = length - listenEndSlack;
    final needed = share < reachable ? share : reachable;
    return needed < cap ? needed : cap;
  }

  @override
  bool operator ==(Object other) =>
      other is ListenThreshold &&
      other.minutes == minutes &&
      other.percent == percent;

  @override
  int get hashCode => Object.hash(minutes, percent);

  @override
  String toString() => 'ListenThreshold($minutes min, $percent %)';
}

/// Whether [listened] makes a listen of a track that is [length] long
/// (STAT-01): longer than 30 s, and heard for the [threshold] (by default
/// half of it or 4 minutes, whichever is less). An unknown [length] needs
/// the threshold's minutes.
bool qualifiesAsListen(
  Duration listened,
  Duration? length, [
  ListenThreshold threshold = ListenThreshold.standard,
]) {
  if (length != null && length <= listenMinTrackLength) return false;
  return listened >= threshold.requiredFor(length);
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
