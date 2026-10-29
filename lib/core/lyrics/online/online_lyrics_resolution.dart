import '../../database/online_lyrics_queries.dart';
import 'online_lyrics_entries.dart';
import 'playing_lyrics_status.dart';

/// How long a "no match" answer is trusted before the provider is asked
/// again.
const notFoundTtl = Duration(days: 14);

Duration? _delta(int? remoteMs, Duration? song) {
  if (remoteMs == null || song == null) return null;
  final diff = Duration(milliseconds: remoteMs) - song;
  return diff.isNegative ? -diff : diff;
}

/// The status a user's pick gives, or `null` when it gives none: a skip,
/// or a pick whose text has no usable line.
PlayingLyricsStatus? statusFromPick(
  String uri,
  LyricsPinEntry pin,
  Duration? songDuration,
) {
  final providerId = pin.providerId;
  final remoteId = pin.remoteId;
  if (providerId == null || remoteId == null) return null;
  final origin = OnlineLyricsOrigin(
    providerId: providerId,
    remoteId: remoteId,
    pinned: true,
    durationDelta: _delta(pin.remoteDurationMs, songDuration),
  );
  final lyrics = pin.lyrics;
  if (lyrics != null) return LyricsFound(uri, lyrics, origin: origin);
  if (pin.instrumental) {
    return LyricsNone(uri, LyricsNoneReason.instrumental, origin: origin);
  }
  return null;
}

/// The status the cached answers give, or `null` for a miss (nothing cached,
/// or only "no match" answers older than [notFoundTtl]). [entries] are in
/// registry order. Lyrics beat an instrumental record, which beats a recent
/// "no match". A found entry with neither text nor instrumental flag is
/// unusable and counts as "no match" whatever its age, so it never causes a
/// new lookup.
PlayingLyricsStatus? statusFromCache(
  String uri,
  List<OnlineLyricsEntry> entries,
  DateTime now,
  Duration? songDuration,
) {
  OnlineLyricsOrigin originOf(OnlineLyricsEntry e) => OnlineLyricsOrigin(
    providerId: e.providerId,
    remoteId: e.remoteId ?? '',
    pinned: false,
    durationDelta: _delta(e.remoteDurationMs, songDuration),
  );
  final found = entries
      .where((e) => e.status == OnlineLyricsStatus.found)
      .toList();
  for (final e in found) {
    final lyrics = e.lyrics;
    if (lyrics != null) return LyricsFound(uri, lyrics, origin: originOf(e));
  }
  for (final e in found) {
    if (e.instrumental) {
      return LyricsNone(
        uri,
        LyricsNoneReason.instrumental,
        origin: originOf(e),
      );
    }
  }
  final unusable = found.isNotEmpty;
  final recent = entries.any(
    (e) =>
        e.status == OnlineLyricsStatus.notFound &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(e.fetchedAt)) <
            notFoundTtl,
  );
  return unusable || recent ? LyricsNone(uri, LyricsNoneReason.notFound) : null;
}
