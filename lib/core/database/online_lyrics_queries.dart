import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import 'library_database.dart';
import 'lyrics_plugin_spec.dart';

export 'lyrics_choice_queries.dart';

final _log = Logger('online_lyrics');
bool _warnedUnknownStatus = false;

/// UTF-8 size of both text columns of one row; NULL columns count as zero.
const _textBytes =
    'COALESCE(LENGTH(CAST(synced_text AS BLOB)), 0) '
    '+ COALESCE(LENGTH(CAST(plain_text AS BLOB)), 0)';

/// The `status` values an `online_lyrics` row can hold.
enum OnlineLyricsStatus {
  found('found'),
  notFound('not_found');

  const OnlineLyricsStatus(this.value);

  /// The text stored in the `status` column.
  final String value;

  static OnlineLyricsStatus? parse(String value) =>
      values.where((s) => s.value == value).firstOrNull;
}

extension OnlineLyricsRowStatus on OnlineLyricsRow {
  /// Null for a status this build does not know.
  OnlineLyricsStatus? get lookupStatus => OnlineLyricsStatus.parse(status);
}

/// Queries on the online lyrics tables; see the invariants in
/// `online_lyrics_tables.dart`.
extension OnlineLyricsQueries on LibraryDatabase {
  /// Every provider's known row for one metadata key. Rows with an unknown
  /// status are left out (one warning per run, status only).
  Stream<List<OnlineLyricsRow>> watchOnlineLyrics(String cacheKey) {
    return (select(
      onlineLyrics,
    )..where((t) => t.cacheKey.equals(cacheKey))).watch().map((rows) {
      final known = <OnlineLyricsRow>[];
      for (final row in rows) {
        if (row.lookupStatus != null) {
          known.add(row);
        } else if (!_warnedUnknownStatus) {
          _warnedUnknownStatus = true;
          _log.warning('Ignoring online lyrics row with status ${row.status}');
        }
      }
      return known;
    });
  }

  /// Inserts the row, or replaces the whole row with the same (cache_key,
  /// provider_id); columns the new row leaves out are reset, not kept. Other
  /// providers' rows stay.
  ///
  /// A plugin source's row (id starting with `plugin-`) is saved only while
  /// that plugin's record exists and is not removed, so a lookup that
  /// outlived an uninstall leaves no orphan row. Returns whether a row was
  /// written; LRCLIB rows always are.
  Future<bool> saveOnlineLyrics(OnlineLyricsCompanion row) async {
    if (!isLyricsPluginId(row.providerId.value)) {
      await into(onlineLyrics).insert(row, mode: InsertMode.insertOrReplace);
      return true;
    }
    final changed = await customUpdate(
      'INSERT OR REPLACE INTO online_lyrics (cache_key, provider_id, status, '
      'remote_id, synced_text, plain_text, instrumental, remote_duration_ms, '
      'fetched_at) '
      'SELECT ?, install_id, ?, ?, ?, ?, ?, ?, ? FROM lyrics_plugins '
      'WHERE install_id = ? AND removed_at IS NULL',
      variables: [
        Variable<String>(row.cacheKey.value),
        Variable<String>(row.status.value),
        Variable<String>(row.remoteId.present ? row.remoteId.value : null),
        Variable<String>(row.syncedText.present ? row.syncedText.value : null),
        Variable<String>(row.plainText.present ? row.plainText.value : null),
        Variable<bool>(row.instrumental.present && row.instrumental.value),
        Variable<int>(
          row.remoteDurationMs.present ? row.remoteDurationMs.value : null,
        ),
        Variable<int>(row.fetchedAt.value),
        Variable<String>(row.providerId.value),
      ],
      updates: {onlineLyrics},
      updateKind: UpdateKind.insert,
    );
    return changed > 0;
  }

  /// Removes every provider's row for one metadata key (forces a new lookup).
  Future<void> deleteOnlineLyrics(String cacheKey) =>
      (delete(onlineLyrics)..where((t) => t.cacheKey.equals(cacheKey))).go();

  /// The song's lyrics choice and pick, or null.
  Stream<LyricsPinRow?> watchLyricsPin(String trackKey) => (select(
    lyricsPins,
  )..where((t) => t.trackKey.equals(trackKey))).watchSingleOrNull().distinct();

  /// Row counts and the UTF-8 size of all stored lyrics text. Any status
  /// but found counts as not found, so no stored row goes uncounted. Pins
  /// are split into picks (a chosen match) and choices (every other pin,
  /// whatever its mode), so no pin is counted twice. A song with both an
  /// automatic row and a pick may still be counted in both tables: their
  /// keys differ, so the song total is an approximation.
  Stream<
    ({int found, int notFound, int picks, int choices, int rejects, int bytes})
  >
  watchOnlineLyricsStats() {
    return customSelect(
      'SELECT '
      "(SELECT COUNT(*) FROM online_lyrics WHERE status = 'found') AS found, "
      // Any status but found, so a row from a newer build still counts.
      "(SELECT COUNT(*) FROM online_lyrics WHERE status <> 'found') "
      'AS not_found, '
      '(SELECT COUNT(*) FROM lyrics_pins WHERE remote_id IS NOT NULL) '
      'AS picks, '
      '(SELECT COUNT(*) FROM lyrics_pins WHERE remote_id IS NULL) '
      'AS choices, '
      '(SELECT COUNT(*) FROM online_lyrics_rejects) AS rejects, '
      '(SELECT COALESCE(SUM($_textBytes), 0) FROM online_lyrics) '
      '+ (SELECT COALESCE(SUM($_textBytes), 0) FROM lyrics_pins) AS bytes',
      readsFrom: {onlineLyrics, lyricsPins, onlineLyricsRejects},
    ).watchSingle().map(
      (r) => (
        found: r.read<int>('found'),
        notFound: r.read<int>('not_found'),
        picks: r.read<int>('picks'),
        choices: r.read<int>('choices'),
        rejects: r.read<int>('rejects'),
        bytes: r.read<int>('bytes'),
      ),
    );
  }

  /// Empties all three tables in one transaction and returns the rows
  /// removed. Also deletes every removed plugin record (nothing points to
  /// them once the three tables are empty; they are not counted). Never
  /// touches `.lrc` files.
  Future<int> clearOnlineLyrics() {
    return transaction(() async {
      var removed = 0;
      removed += await delete(onlineLyrics).go();
      removed += await delete(lyricsPins).go();
      removed += await delete(onlineLyricsRejects).go();
      await (delete(lyricsPlugins)..where((t) => t.removedAt.isNotNull())).go();
      return removed;
    });
  }

  /// The tag fields of the library song at [path], fresh after every rescan;
  /// null when the path is not in the library.
  Stream<({String title, String? artist, String? album, int? durationMs})?>
  watchTrackLyricsFields(String path) {
    return (select(tracks)..where((t) => t.path.equals(path)))
        .watchSingleOrNull()
        .map(
          (t) => t == null
              ? null
              : (
                  title: t.title,
                  artist: t.artist,
                  album: t.album,
                  durationMs: t.durationMs,
                ),
        )
        .distinct();
  }
}
