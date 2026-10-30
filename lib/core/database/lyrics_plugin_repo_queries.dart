import 'dart:convert';

import 'package:drift/drift.dart';

import 'library_database.dart';
import 'lyrics_plugin_spec.dart';

/// Queries on `lyrics_plugin_repos`; see invariant 9 in
/// `lyrics_plugin_tables.dart`.
extension LyricsPluginRepoQueries on LibraryDatabase {
  Stream<List<LyricsPluginRepoRow>> watchLyricsPluginRepos() =>
      (select(lyricsPluginRepos)..orderBy([
            (t) => OrderingTerm.asc(t.addedAt),
            (t) => OrderingTerm.asc(t.url),
          ]))
          .watch();

  /// Adds a repository; false, and nothing changed, when [url] is known.
  Future<bool> addLyricsPluginRepo(
    String url, {
    required String name,
    String? author,
    required int now,
  }) async {
    final changed = await customUpdate(
      'INSERT OR IGNORE INTO lyrics_plugin_repos (url, name, author, added_at) '
      'VALUES (?, ?, ?, ?)',
      variables: [
        Variable<String>(url),
        Variable<String>(name),
        Variable<String>(author),
        Variable<int>(now),
      ],
      updates: {lyricsPluginRepos},
      updateKind: UpdateKind.insert,
    );
    return changed > 0;
  }

  /// Removes a repository (installed plugins are not touched); false when
  /// [url] is unknown.
  Future<bool> removeLyricsPluginRepo(String url) async =>
      await (delete(lyricsPluginRepos)..where((t) => t.url.equals(url))).go() >
      0;

  /// Stores the outcome of one fetch. With [catalog] (JSON text) the catalog
  /// is replaced, `last_fetched_at` is [now] and `last_error` is cleared. With
  /// [error] (a kind string) only `last_error` changes: the last good catalog
  /// and its time stay. Exactly one of the two must be given. A catalog over
  /// 1 MiB is `tooLarge` and nothing is written; an unknown [url] is
  /// `skipped`.
  Future<LyricsPluginWrite> saveLyricsPluginRepoFetch(
    String url, {
    String? catalog,
    String? error,
    required int now,
  }) async {
    if ((catalog == null) == (error == null)) {
      throw ArgumentError('Give exactly one of catalog and error');
    }
    if (catalog != null &&
        utf8.encode(catalog).length > lyricsPluginCatalogMaxBytes) {
      return LyricsPluginWrite.tooLarge;
    }
    final changed =
        await (update(
          lyricsPluginRepos,
        )..where((t) => t.url.equals(url))).write(
          catalog != null
              ? LyricsPluginReposCompanion(
                  catalog: Value(catalog),
                  lastFetchedAt: Value(now),
                  lastError: const Value(null),
                )
              : LyricsPluginReposCompanion(lastError: Value(error)),
        );
    return changed > 0 ? LyricsPluginWrite.written : LyricsPluginWrite.skipped;
  }
}
