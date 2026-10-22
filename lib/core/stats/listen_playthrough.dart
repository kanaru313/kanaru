import '../player/track.dart';
import 'listen_accumulator.dart';

/// Where a playthrough stands with its `plays` row. `pending` means the
/// insert is queued and counts as a row; `dead` is final (not a library
/// track, or the insert failed).
enum PlayRow { none, pending, stored, dead }

/// One playthrough of one track: from a fresh start to the next one, a stop,
/// or the recorder being switched off. The track and its path are captured at
/// the start and never re-read from later player states.
class ListenPlaythrough {
  ListenPlaythrough({
    required this.marker,
    required this.track,
    required this.path,
    required this.acc,
  }) : row = path == null ? PlayRow.dead : PlayRow.none;

  final int marker;
  final Track track;
  final String? path;
  final ListenAccumulator acc;
  PlayRow row;
  int? rowId;
  int? playedAt;

  /// First positive engine duration; the library duration until it arrives.
  Duration? lockedLength;

  /// Listening time handed to the write chain so far.
  Duration queued = Duration.zero;

  Duration? get length {
    final fallback = track.duration;
    return lockedLength ??
        (fallback != null && fallback > Duration.zero ? fallback : null);
  }
}
