import 'package:drift/drift.dart';

import 'library_database.steps.dart';

/// Schema 10 to 11: the lyrics plugin tables `lyrics_plugins`,
/// `lyrics_source_prefs`, `lyrics_plugin_repos` and `lyrics_plugin_data`, and
/// the unique index on `lyrics_plugins (repo_url, repo_slug)`. All start
/// empty; no row for `lrclib` in `lyrics_source_prefs` means enabled.
///
/// Runs in one transaction and can run again on a half-migrated file (drift
/// writes `user_version` after the step): each table and the index are
/// created only when `sqlite_master` lacks them.
Future<void> migrateLibraryToSchema11(
  GeneratedDatabase db,
  Migrator m,
  Schema11 schema,
) {
  return db.transaction(() async {
    final existing = {
      for (final row
          in await db.customSelect('SELECT name FROM sqlite_master').get())
        row.read<String>('name'),
    };
    final tables = {
      'lyrics_plugins': schema.lyricsPlugins,
      'lyrics_source_prefs': schema.lyricsSourcePrefs,
      'lyrics_plugin_repos': schema.lyricsPluginRepos,
      'lyrics_plugin_data': schema.lyricsPluginData,
    };
    for (final MapEntry(:key, :value) in tables.entries) {
      if (!existing.contains(key)) await m.create(value);
    }
    if (!existing.contains('lyrics_plugins_repo_unique')) {
      await m.create(schema.lyricsPluginsRepoUnique);
    }
  });
}
