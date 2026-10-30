import 'package:drift/drift.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';

LyricsPluginSpec pluginSpec({
  String name = 'Demo',
  int version = 1,
  String packageDir = 'plugin-a/v1-100',
  String configSchema = '[]',
  List<String> hosts = const ['api.example.com'],
  String? repoUrl,
  String? repoSlug,
}) => LyricsPluginSpec(
  name: name,
  version: version,
  apiVersion: 1,
  hosts: hosts,
  configSchema: configSchema,
  packageDir: packageDir,
  sourceKind: repoUrl == null
      ? LyricsPluginSourceKind.file
      : LyricsPluginSourceKind.repo,
  sourceName: repoUrl == null ? 'demo.zip' : 'Demo repo',
  repoUrl: repoUrl,
  repoSlug: repoSlug,
);

OnlineLyricsCompanion lyricsRow(
  String key,
  String provider, {
  String status = 'found',
  String? plain = 'text',
}) => OnlineLyricsCompanion.insert(
  cacheKey: key,
  providerId: provider,
  status: status,
  remoteId: Value(status == 'found' ? 'r1' : null),
  plainText: Value(plain),
  fetchedAt: 1,
);

Future<int> countRows(LibraryDatabase db, String table) async =>
    (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
        .read<int>('n');

/// Every row of the tables an uninstall may touch, as comparable text.
Future<List<String>> snapshotPluginTables(LibraryDatabase db) async {
  final out = <String>[];
  for (final table in [
    'lyrics_plugins',
    'lyrics_plugin_data',
    'lyrics_source_prefs',
    'online_lyrics',
    'lyrics_pins',
    'online_lyrics_rejects',
  ]) {
    final rows = await db.customSelect('SELECT * FROM $table').get();
    out.add('$table: ${rows.map((r) => r.data).toList()}');
  }
  return out;
}

/// Gives [provider] a pin, a found row, a reject and a not-found row.
Future<void> seedPluginReferences(
  LibraryDatabase db,
  String provider, {
  bool found = true,
  bool notFound = true,
  bool pin = false,
  bool reject = false,
}) async {
  if (found) await db.saveOnlineLyrics(lyricsRow('k-found', provider));
  if (notFound) {
    await db.saveOnlineLyrics(
      lyricsRow('k-miss', provider, status: 'not_found'),
    );
  }
  if (pin) {
    await db.customStatement(
      'INSERT INTO lyrics_pins (track_key, provider_id, mode, remote_id, '
      "pinned_at) VALUES ('/m/a', '$provider', 'online', 'r1', 1)",
    );
  }
  if (reject) {
    await db.customStatement(
      'INSERT INTO online_lyrics_rejects (cache_key, provider_id, remote_id, '
      "rejected_at) VALUES ('k-found', '$provider', 'bad', 1)",
    );
  }
}
