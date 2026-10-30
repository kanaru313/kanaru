import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/library_database.dart';
import '../../database/library_startup.dart';
import '../../database/online_lyrics_queries.dart';
import 'lyrics_provider_registry.dart';
import 'lyrics_source_names.dart';
import 'online_lyrics_entries.dart';

export 'online_lyrics_backoff.dart';
export 'online_lyrics_entries.dart';

/// What a pin row is told apart by; a rewrite of the same pick and mode is
/// the same, a change of mode alone is not.
String _pinIdentity(LyricsPinRow? row) => row == null
    ? ''
    : '${row.providerId}|${row.remoteId}|${row.pinnedAt}|${row.mode}';

/// The song's choice and pick with the text parsed once, `null` when it has
/// no row. Drift emits again on any write to the table, so unchanged rows are
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

/// Enabled sources first, in the user's order, then the other known sources
/// by name. Rows of sources that are not known are dropped; rows of known
/// sources that are not enabled stay only when they hold lyrics, so a
/// disabled source keeps showing what it found but never counts as a miss.
List<OnlineLyricsRow> _listedRows(
  List<OnlineLyricsRow> rows,
  List<String> enabled,
  Map<String, LyricsSourceName> names,
) {
  int rank(String id) {
    final i = enabled.indexOf(id);
    return i >= 0 ? i : enabled.length;
  }

  String nameOf(String id) => names[id]?.displayName.toLowerCase() ?? id;

  return [
    for (final row in rows)
      if (names.containsKey(row.providerId) &&
          (enabled.contains(row.providerId) ||
              row.lookupStatus == OnlineLyricsStatus.found))
        row,
  ]..sort((a, b) {
    final byRank = rank(a.providerId).compareTo(rank(b.providerId));
    if (byRank != 0) return byRank;
    final byName = nameOf(a.providerId).compareTo(nameOf(b.providerId));
    return byName != 0 ? byName : a.providerId.compareTo(b.providerId);
  });
}

/// The cached answers for one metadata key: enabled sources in the user's
/// order, then the lyrics of other known sources, with text parsed once.
/// Rows of unknown sources are ignored. Loading until the sources are
/// loaded. The list is only re-emitted when a row is added, replaced or
/// removed.
final onlineLyricsCacheProvider = StreamProvider.autoDispose
    .family<List<OnlineLyricsEntry>, String>((ref, cacheKey) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(const []);
      // An empty stream never emits: the provider stays loading.
      if (!ref.watch(lyricsSourcesLoadedProvider)) return const Stream.empty();
      final enabled = [
        for (final r in ref.watch(lyricsProvidersProvider)) r.id,
      ];
      final names = ref.watch(lyricsSourceNamesProvider);
      return db
          .watchOnlineLyrics(cacheKey)
          .map((rows) => _listedRows(rows, enabled, names))
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
