import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/library_database.dart';
import '../../database/library_startup.dart';
import '../../database/online_lyrics_queries.dart';
import 'lyrics_provider_registry.dart';
import 'online_lyrics_entries.dart';

export 'online_lyrics_backoff.dart';
export 'online_lyrics_entries.dart';

/// What a pin row is told apart by; a rewrite of the same pick is the same.
String _pinIdentity(LyricsPinRow? row) =>
    row == null ? '' : '${row.providerId}|${row.remoteId}|${row.pinnedAt}';

/// The song's pick or skip with its text parsed once, `null` when it has
/// none. Drift emits again on any write to the table, so unchanged rows are
/// dropped before parsing: the same [Lyrics] instance is kept while the pin
/// is.
final lyricsPinProvider = StreamProvider.autoDispose
    .family<LyricsPinEntry?, String>((ref, trackKey) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(null);
      return db
          .watchLyricsPin(trackKey)
          .distinct((a, b) => _pinIdentity(a) == _pinIdentity(b))
          .map((row) => row == null ? null : LyricsPinEntry.fromRow(row));
    }, retry: (_, _) => null);

String _rowIdentity(OnlineLyricsRow row) =>
    '${row.providerId}|${row.status}|${row.remoteId}|${row.fetchedAt}';

/// The cached answers for one metadata key, in registry order, with text
/// parsed once. Rows of providers that are not registered are ignored. The
/// list is only re-emitted when a row is added, replaced or removed.
final onlineLyricsCacheProvider = StreamProvider.autoDispose
    .family<List<OnlineLyricsEntry>, String>((ref, cacheKey) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(const []);
      final order = [for (final r in ref.watch(lyricsProvidersProvider)) r.id];
      return db
          .watchOnlineLyrics(cacheKey)
          .map((rows) {
            final known =
                [
                  for (final row in rows)
                    if (order.contains(row.providerId)) row,
                ]..sort(
                  (a, b) => order
                      .indexOf(a.providerId)
                      .compareTo(order.indexOf(b.providerId)),
                );
            return known;
          })
          .distinct(
            (a, b) => listEquals(
              [for (final r in a) _rowIdentity(r)],
              [for (final r in b) _rowIdentity(r)],
            ),
          )
          .map(
            (rows) => [
              for (final row in rows)
                OnlineLyricsEntry.fromRow(row, row.lookupStatus!),
            ],
          );
    }, retry: (_, _) => null);

/// Row counts and text size of everything saved for online lyrics, live.
/// Zeros without a library database.
final onlineLyricsStatsProvider =
    StreamProvider.autoDispose<
      ({
        int found,
        int notFound,
        int picks,
        int choices,
        int rejects,
        int bytes,
      })
    >((ref) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) {
        return Stream.value((
          found: 0,
          notFound: 0,
          picks: 0,
          choices: 0,
          rejects: 0,
          bytes: 0,
        ));
      }
      return db.watchOnlineLyricsStats();
    }, retry: (_, _) => null);
