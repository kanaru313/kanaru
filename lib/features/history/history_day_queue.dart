import '../../core/database/history_rows.dart';
import '../../core/indexer/cover_paths.dart';
import '../../core/player/track.dart';
import '../../shared/play_tracks.dart';

/// The queue for [track] as the library knows it. The player is only ever
/// handed the library row's path, never the path a play remembers: a play
/// outlives its file, and the library row is the one the indexer vetted.
Track historyTrackOf(HistoryPlayRow row, String? covers) {
  final track = row.track!;
  return trackFromItem(
    path: track.path,
    title: track.title,
    artist: track.artist,
    durationMs: track.durationMs,
    artPath: coverPath(covers, track.coverKey),
  );
}

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
