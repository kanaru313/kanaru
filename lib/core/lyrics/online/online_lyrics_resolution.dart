import '../../database/online_lyrics_queries.dart';
import '../lyrics.dart';
import 'lyrics_choice.dart';
import 'online_lyrics_entries.dart';
import 'online_lyrics_lookups.dart';
import 'playing_lyrics_status.dart';

/// How long a "no match" answer is trusted before the provider is asked
/// again.
const notFoundTtl = Duration(days: 14);

Duration? _delta(int? remoteMs, Duration? song) {
  if (remoteMs == null || song == null) return null;
  final diff = Duration(milliseconds: remoteMs) - song;
  return diff.isNegative ? -diff : diff;
}

/// The status a user's pick gives, or `null` when it gives none: no pick, or
/// a pick whose text has no usable line.
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

/// What a song resolves to: the status, and the choice that produced it. The
/// effective choice differs from the chosen one when the choice cannot be
/// honoured (`local` without local lyrics, `online` without a usable pick).
typedef LyricsResolution = ({
  PlayingLyricsStatus status,
  LyricsChoice effective,
});

/// Resolves a song's lyrics by its stored choice, the one place the order is
/// written. Pure: it reads nothing and writes nothing.
///
/// * `off`: [LyricsNoneReason.off]; [fromCacheOrLookup] is not called.
/// * `online` with a usable pick: that pick.
/// * otherwise (`local`, `auto`, `online` with an unusable pick): [local]
///   when there is some; else, for a local file, [fromCacheOrLookup] (the
///   cache, then a lookup); else no lyrics.
///
/// [local] is the song's own tag or `.lrc` lyrics, already checked to belong
/// to [uri]. [fromCacheOrLookup] is called at most once, and only on the last
/// branch, so a caller can watch lookup providers inside it.
LyricsResolution resolveChoice({
  required String uri,
  required LyricsPinEntry? pin,
  required Duration? songDuration,
  required Lyrics? local,
  required bool isLocalFile,
  required PlayingLyricsStatus Function() fromCacheOrLookup,
}) {
  final chosen = pin?.choice ?? LyricsChoice.auto;
  if (chosen == LyricsChoice.off) {
    return (
      status: LyricsNone(uri, LyricsNoneReason.off),
      effective: LyricsChoice.off,
    );
  }
  if (chosen == LyricsChoice.online && pin != null) {
    final picked = statusFromPick(uri, pin, songDuration);
    if (picked != null) {
      return (status: picked, effective: LyricsChoice.online);
    }
  }
  // Local was honoured only when it was asked for; otherwise it simply won
  // the automatic order.
  final asked = chosen == LyricsChoice.local;
  if (local != null) {
    return (
      status: LyricsFound(uri, local),
      effective: asked ? LyricsChoice.local : LyricsChoice.auto,
    );
  }
  return (
    status: isLocalFile
        ? fromCacheOrLookup()
        : LyricsNone(uri, LyricsNoneReason.noLyrics),
    effective: LyricsChoice.auto,
  );
}

/// The status of a song that has neither local lyrics nor a usable cache
/// entry, from the state of its lookup. Order matters:
///
/// * [lookup] running: searching;
/// * an automatic lookup is due ([autoProviderId], never set while paused):
///   searching, so an old failure is not shown while a new lookup is about
///   to run;
/// * [lookup] failed: the error, which the pause that follows it never hides;
/// * the pause is on and an automatic lookup is [wanted]: paused until
///   [pausedUntil];
/// * otherwise no lyrics.
PlayingLyricsStatus statusFromLookup({
  required String uri,
  required LookupState? lookup,
  required bool wanted,
  required DateTime? pausedUntil,
  required DateTime now,
  required String? autoProviderId,
}) {
  final paused = pausedUntil != null && now.isBefore(pausedUntil);
  return switch (lookup) {
    LookupRunning(:final providerId) => LyricsSearching(uri, providerId),
    _ when autoProviderId != null => LyricsSearching(uri, autoProviderId),
    LookupFailed(:final kind) => LyricsNone(
      uri,
      LyricsNoneReason.error,
      failure: kind,
    ),
    _ when paused && wanted => LyricsNone(
      uri,
      LyricsNoneReason.paused,
      resumeAt: pausedUntil,
    ),
    _ => LyricsNone(uri, LyricsNoneReason.noLyrics),
  };
}
