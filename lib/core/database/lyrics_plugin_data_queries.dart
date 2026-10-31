import 'dart:convert';

import 'package:drift/drift.dart';

import 'library_database.dart';
import 'lyrics_plugin_spec.dart';

/// UTF-8 size of both text columns of one `online_lyrics` row.
const _textBytes =
    'COALESCE(LENGTH(CAST(synced_text AS BLOB)), 0) '
    '+ COALESCE(LENGTH(CAST(plain_text AS BLOB)), 0)';

/// Queries on `lyrics_plugin_data` and a plugin's saved lyrics; see invariant
/// 7 in `lyrics_plugin_tables.dart`.
extension LyricsPluginDataQueries on LibraryDatabase {
  Future<LyricsPluginDataRow?> lyricsPluginDataFor(String installId) => (select(
    lyricsPluginData,
  )..where((t) => t.installId.equals(installId))).getSingleOrNull();

  /// Replaces the plugin's non-secret config values. Writes only while the
  /// record exists and is not removed; over 64 KiB is `tooLarge`.
  Future<LyricsPluginWrite> setLyricsPluginConfigValues(
    String installId,
    Map<String, Object?> values,
  ) => _writeData(installId, 'config_values', values);

  /// Replaces the plugin's localStorage with the map a finished run returned.
  /// Guarded: writes only while the record exists, is not removed and its
  /// `updated_at` still equals [expectedUpdatedAt] (the value the run began
  /// with), so a run that outlived an uninstall or an update writes nothing
  /// (`skipped`). Over 64 KiB is `tooLarge`.
  Future<LyricsPluginWrite> setLyricsPluginStorage(
    String installId,
    Map<String, Object?> storage, {
    required int expectedUpdatedAt,
  }) => _writeData(
    installId,
    'storage',
    storage,
    expectedUpdatedAt: expectedUpdatedAt,
  );

  Future<LyricsPluginWrite> _writeData(
    String installId,
    String column,
    Map<String, Object?> value, {
    int? expectedUpdatedAt,
  }) async {
    final text = jsonEncode(value);
    if (utf8.encode(text).length > lyricsPluginDataMaxBytes) {
      return LyricsPluginWrite.tooLarge;
    }
    // INSERT ... SELECT inserts nothing when the record is gone, removed or
    // changed; the row exists for every live plugin, so the upsert branch is
    // the normal one.
    final changed = await customUpdate(
      'INSERT INTO lyrics_plugin_data (install_id, $column) '
      'SELECT install_id, ?1 FROM lyrics_plugins '
      'WHERE install_id = ?2 AND removed_at IS NULL '
      '${expectedUpdatedAt == null ? '' : 'AND updated_at = ?3 '}'
      'ON CONFLICT(install_id) DO UPDATE SET $column = excluded.$column',
      variables: [
        Variable<String>(text),
        Variable<String>(installId),
        if (expectedUpdatedAt != null) Variable<int>(expectedUpdatedAt),
      ],
      updates: {lyricsPluginData},
      updateKind: UpdateKind.insert,
    );
    return changed > 0 ? LyricsPluginWrite.written : LyricsPluginWrite.skipped;
  }

  /// What the plugin keeps: localStorage bytes, and the found rows it saved
  /// with the UTF-8 size of their text. Zero for a plugin with none; a storage
  /// that is the empty object `{}` counts 0 bytes.
  Future<({int storageBytes, int foundCount, int textBytes})>
  lyricsPluginDataStats(String installId) async {
    final row = await customSelect(
      'SELECT '
      "(SELECT COALESCE(SUM(CASE WHEN storage = '{}' THEN 0 "
      'ELSE LENGTH(CAST(storage AS BLOB)) END), 0) '
      'FROM lyrics_plugin_data WHERE install_id = ?1) AS storage_bytes, '
      '(SELECT COUNT(*) FROM online_lyrics '
      "WHERE provider_id = ?1 AND status = 'found') AS found_count, "
      '(SELECT COALESCE(SUM($_textBytes), 0) FROM online_lyrics '
      "WHERE provider_id = ?1 AND status = 'found') AS text_bytes",
      variables: [Variable<String>(installId)],
      readsFrom: {lyricsPluginData, onlineLyrics},
    ).getSingle();
    return (
      storageBytes: row.read<int>('storage_bytes'),
      foundCount: row.read<int>('found_count'),
      textBytes: row.read<int>('text_bytes'),
    );
  }

  /// Deletes this plugin's `online_lyrics` rows (found and not found); pins
  /// and rejects stay. If the record is a removed one and no row, pin or
  /// reject names it any more, the record is deleted in the same
  /// transaction. Returns the rows removed.
  Future<int> clearLyricsPluginSavedLyrics(String installId) {
    return transaction(() async {
      final removed = await (delete(
        onlineLyrics,
      )..where((t) => t.providerId.equals(installId))).go();
      await customUpdate(
        'DELETE FROM lyrics_plugins WHERE install_id = ?1 '
        'AND removed_at IS NOT NULL '
        'AND NOT EXISTS (SELECT 1 FROM online_lyrics WHERE provider_id = ?1) '
        'AND NOT EXISTS (SELECT 1 FROM lyrics_pins WHERE provider_id = ?1) '
        'AND NOT EXISTS (SELECT 1 FROM online_lyrics_rejects '
        'WHERE provider_id = ?1)',
        variables: [Variable<String>(installId)],
        updates: {lyricsPlugins},
        updateKind: UpdateKind.delete,
      );
      return removed;
    });
  }
}
