import '../../core/database/history_rows.dart';
import '../../core/player/track.dart';
import 'history_queue_track.dart';

/// The queue entry for a most-played row's library song, or null when the
/// song is gone. The player only gets the `tracks` row path (never the path
/// the plays remember). [covers] is the cover thumbnail folder, null when
/// covers are off.
Track? historyTopTrackOf(HistoryTopRow row, String? covers) {
  final track = row.track;
  return track == null ? null : historyQueueTrack(track, covers);
}

/// The songs of [rows] that can play, in rank order.
List<Track> historyTopPlayable(List<HistoryTopRow> rows, String? covers) => [
  for (final row in rows) ?historyTopTrackOf(row, covers),
];

/// What a tap on `rows[index]` plays: the playable songs in rank order,
/// starting at the tapped one. Null when that row cannot play.
({List<Track> tracks, int start})? historyTopQueue(
  List<HistoryTopRow> rows,
  int index,
  String? covers,
) {
  if (rows[index].track == null) return null;
  final tracks = <Track>[];
  var start = 0;
  for (var i = 0; i < rows.length; i++) {
    final track = historyTopTrackOf(rows[i], covers);
    if (track == null) continue;
    if (i == index) start = tracks.length;
    tracks.add(track);
  }
  return (tracks: tracks, start: start);
}
