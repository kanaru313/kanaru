import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/library_database.dart';
import '../../database/library_startup.dart';
import '../../database/online_lyrics_queries.dart';
import '../../lyrics_translation/lyrics_content_hash.dart';
import '../lyrics.dart';
import 'lyrics_target.dart';
import 'online_lyrics_streams.dart';
import 'playing_lyrics_status.dart';

/// "Not these lyrics": remembers [origin]'s match as rejected for the
/// song's metadata by id and by the text of [shown] (the lyrics on screen),
/// drops the cached rows with that text, and the song's pick when it is
/// that match. Sends nothing itself: automatic resolution runs again. The
/// hash comes from the same parse that produced [shown] and the stored
/// candidates, so the shown text and the rejected record match.
///
/// The cached copies are read before the write transaction, not inside it.
/// A row a lookup stores in between can survive; that is a small race, as a
/// lookup only runs while no match is shown.
Future<void> rejectOnlineLyrics(
  Ref ref,
  LyricsTarget target,
  OnlineLyricsOrigin origin,
  Lyrics shown,
) async {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final hash = lyricsContentHashOf(shown);
  final cached = await db.watchOnlineLyrics(target.cacheKey).first;
  final duplicates = <(String, String)>{
    for (final row in cached)
      if (row.lookupStatus == OnlineLyricsStatus.found &&
          row.remoteId != null &&
          _hashOfRow(row) == hash)
        (row.providerId, row.remoteId!),
  };
  await db.rejectOnlineLyrics(
    cacheKey: target.cacheKey,
    providerId: origin.providerId,
    remoteId: origin.remoteId,
    contentHash: hash,
    duplicates: duplicates,
    trackKey: target.trackKey,
    now: ref.read(onlineLyricsClockProvider)().millisecondsSinceEpoch,
  );
}

String? _hashOfRow(OnlineLyricsRow row) {
  final lyrics = parseStoredLyrics(
    synced: row.syncedText,
    plain: row.plainText,
  );
  return lyrics == null ? null : lyricsContentHashOf(lyrics);
}
