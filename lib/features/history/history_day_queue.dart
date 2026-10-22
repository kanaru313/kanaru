import '../../core/database/history_rows.dart';
import '../../core/player/track.dart';
import 'history_queue_track.dart';

/// The queue entry for the library song of [row], which must have one.
Track historyTrackOf(HistoryPlayRow row, String? covers) =>
    historyQueueTrack(row.track!, covers);

/// What a tap on [tapped] plays: the songs of its day ([dayRows], in the order
/// shown), each song once at its first appearance, those no longer in the
/// library left out, starting at the tapped song. Null when [tapped] cannot
/// play. [covers] is the cover thumbnail folder, null when covers are off.
({List<Track> tracks, int start})? historyDayQueue(
  List<HistoryPlayRow> dayRows,
  HistoryPlayRow tapped,
  String? covers,
) {
  if (tapped.track == null) return null;
  final tracks = <Track>[];
  final seen = <String>{};
  var start = 0;
  for (final row in dayRows) {
    if (row.track == null || !seen.add(row.path)) continue;
    if (row.path == tapped.path) start = tracks.length;
    tracks.add(historyTrackOf(row, covers));
  }
  // The day was read again and the tapped song is not in it any more.
  if (!seen.contains(tapped.path)) {
    return (tracks: [historyTrackOf(tapped, covers)], start: 0);
  }
  return (tracks: tracks, start: start);
}
