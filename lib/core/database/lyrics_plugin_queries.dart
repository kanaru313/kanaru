import 'dart:convert';

import 'package:drift/drift.dart';

import 'library_database.dart';
import 'lyrics_plugin_spec.dart';

export 'lyrics_plugin_data_queries.dart';
export 'lyrics_plugin_repo_queries.dart';
export 'lyrics_plugin_spec.dart';
export 'lyrics_source_pref_queries.dart';

/// Queries on `lyrics_plugins`; see the invariants in
/// `lyrics_plugin_tables.dart`. Installs, revives and package switches also
/// keep `lyrics_plugin_data` in step; uninstall also clears the plugin's
/// preference and not-found rows, all in one transaction.
extension LyricsPluginQueries on LibraryDatabase {
  /// Every record, removed ones included, ordered by install time.
  Stream<List<LyricsPluginRow>> watchLyricsPluginRecords() =>
      (select(lyricsPlugins)..orderBy([
            (t) => OrderingTerm.asc(t.installedAt),
            (t) => OrderingTerm.asc(t.installId),
          ]))
          .watch();

  Future<LyricsPluginRow?> lyricsPluginById(String installId) => (select(
    lyricsPlugins,
  )..where((t) => t.installId.equals(installId))).getSingleOrNull();

  /// The record installed from [slug] of the repository [url], removed or
  /// not; null when none.
  Future<LyricsPluginRow?> lyricsPluginByRepo(String url, String slug) =>
      (select(lyricsPlugins)
            ..where((t) => t.repoUrl.equals(url) & t.repoSlug.equals(slug)))
          .getSingleOrNull();

  /// Adds a record and its empty data row. Throws [ArgumentError] when
  /// [installId] lacks the `plugin-` prefix, and another error when it or the
  /// (repo url, slug) pair is taken; nothing is written then.
  Future<void> insertLyricsPlugin(
    String installId,
    LyricsPluginSpec spec, {
    required int now,
  }) async {
    _checkPluginId(installId);
    return transaction(() async {
      await into(lyricsPlugins).insert(
        LyricsPluginsCompanion.insert(
          installId: installId,
          name: spec.name,
          author: Value(spec.author),
          description: Value(spec.description),
          version: spec.version,
          apiVersion: spec.apiVersion,
          hosts: jsonEncode(spec.hosts),
          configSchema: spec.configSchema,
          packageDir: spec.packageDir,
          sourceKind: spec.sourceKind.value,
          sourceName: spec.sourceName,
          repoUrl: Value(spec.repoUrl),
          repoSlug: Value(spec.repoSlug),
          installedAt: now,
          updatedAt: now,
        ),
      );
      await into(lyricsPluginData).insert(
        LyricsPluginDataCompanion.insert(installId: installId),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  /// Brings a removed record back under the same id with [spec] (it may be a
  /// newer version or come from another source), as a fresh install:
  /// `installed_at` is [now], config and storage start empty, and any old
  /// preference row is dropped. `updated_at` is [now], or one more than
  /// before if that is not later, so a run that began before the uninstall
  /// can never write into the new install. Returns the new `updated_at`, or
  /// null (nothing written) when the record is missing or not removed.
  /// Throws [ArgumentError] when [installId] lacks the `plugin-` prefix.
  Future<int?> reviveLyricsPlugin(
    String installId,
    LyricsPluginSpec spec, {
    required int now,
  }) async {
    _checkPluginId(installId);
    return transaction(() async {
      final changed = await customUpdate(
        'UPDATE lyrics_plugins SET name = ?1, author = ?2, description = ?3, '
        'version = ?4, api_version = ?5, hosts = ?6, config_schema = ?7, '
        'package_dir = ?8, source_kind = ?9, source_name = ?10, '
        'repo_url = ?11, repo_slug = ?12, installed_at = ?13, '
        'updated_at = MAX(?13, updated_at + 1), removed_at = NULL '
        'WHERE install_id = ?14 AND removed_at IS NOT NULL',
        variables: [
          Variable<String>(spec.name),
          Variable<String>(spec.author),
          Variable<String>(spec.description),
          Variable<int>(spec.version),
          Variable<int>(spec.apiVersion),
          Variable<String>(jsonEncode(spec.hosts)),
          Variable<String>(spec.configSchema),
          Variable<String>(spec.packageDir),
          Variable<String>(spec.sourceKind.value),
          Variable<String>(spec.sourceName),
          Variable<String>(spec.repoUrl),
          Variable<String>(spec.repoSlug),
          Variable<int>(now),
          Variable<String>(installId),
        ],
        updates: {lyricsPlugins},
        updateKind: UpdateKind.update,
      );
      if (changed == 0) return null;
      await into(lyricsPluginData).insert(
        LyricsPluginDataCompanion.insert(installId: installId),
        mode: InsertMode.insertOrReplace,
      );
      await (delete(
        lyricsSourcePrefs,
      )..where((t) => t.providerId.equals(installId))).go();
      return (await lyricsPluginById(installId))!.updatedAt;
    });
  }

  /// Points a live record at a new package version: `package_dir`,
  /// `version`, `api_version`, `hosts`, `config_schema`, the descriptive
  /// fields and `updated_at` change in one statement, so a reader sees all
  /// old or all new. Config values, storage, preferences and the install
  /// source are kept. `updated_at` is [now], or one more than before if that
  /// is not later, so a guarded write from an earlier run never matches.
  /// Returns the new `updated_at`, or null (nothing written) when the record
  /// is missing or removed.
  Future<int?> switchLyricsPluginPackage(
    String installId,
    LyricsPluginSpec spec, {
    required int now,
  }) {
    return transaction(() async {
      final changed = await customUpdate(
        'UPDATE lyrics_plugins SET name = ?, author = ?, description = ?, '
        'version = ?, api_version = ?, hosts = ?, config_schema = ?, '
        'package_dir = ?, updated_at = MAX(?, updated_at + 1) '
        'WHERE install_id = ? AND removed_at IS NULL',
        variables: [
          Variable<String>(spec.name),
          Variable<String>(spec.author),
          Variable<String>(spec.description),
          Variable<int>(spec.version),
          Variable<int>(spec.apiVersion),
          Variable<String>(jsonEncode(spec.hosts)),
          Variable<String>(spec.configSchema),
          Variable<String>(spec.packageDir),
          Variable<int>(now),
          Variable<String>(installId),
        ],
        updates: {lyricsPlugins},
        updateKind: UpdateKind.update,
      );
      if (changed == 0) return null;
      return (await lyricsPluginById(installId))!.updatedAt;
    });
  }

  /// Removes a live plugin in one transaction: its not-found rows, data row and
  /// preference row go; the record is deleted when no found row, pin or
  /// reject names its id, else it is marked removed at [now]. Returns what
  /// happened and the record's `config_schema` before the change (null when
  /// missing or already removed, so secrets are deleted once) so the caller
  /// can delete its secrets. If any step fails, no
  /// table changes.
  Future<({LyricsPluginUninstall outcome, String? configSchema})>
  uninstallLyricsPlugin(String installId, {required int now}) {
    return transaction(() async {
      final record = await lyricsPluginById(installId);
      if (record == null) {
        return (outcome: LyricsPluginUninstall.missing, configSchema: null);
      }
      if (record.removedAt != null) {
        // Already gone: its secrets were deleted by the first uninstall.
        return (
          outcome: LyricsPluginUninstall.alreadyRemoved,
          configSchema: null,
        );
      }
      await customUpdate(
        "DELETE FROM online_lyrics WHERE provider_id = ? AND status = 'not_found'",
        variables: [Variable<String>(installId)],
        updates: {onlineLyrics},
        updateKind: UpdateKind.delete,
      );
      await (delete(
        lyricsPluginData,
      )..where((t) => t.installId.equals(installId))).go();
      await (delete(
        lyricsSourcePrefs,
      )..where((t) => t.providerId.equals(installId))).go();
      final referenced = await customSelect(
        'SELECT EXISTS(SELECT 1 FROM online_lyrics WHERE provider_id = ?1) '
        'OR EXISTS(SELECT 1 FROM lyrics_pins WHERE provider_id = ?1) '
        'OR EXISTS(SELECT 1 FROM online_lyrics_rejects '
        'WHERE provider_id = ?1) AS referenced',
        variables: [Variable<String>(installId)],
        readsFrom: {onlineLyrics, lyricsPins, onlineLyricsRejects},
      ).getSingle();
      if (referenced.read<bool>('referenced')) {
        await (update(lyricsPlugins)
              ..where((t) => t.installId.equals(installId)))
            .write(LyricsPluginsCompanion(removedAt: Value(now)));
        return (
          outcome: LyricsPluginUninstall.markedRemoved,
          configSchema: record.configSchema,
        );
      }
      await (delete(
        lyricsPlugins,
      )..where((t) => t.installId.equals(installId))).go();
      return (
        outcome: LyricsPluginUninstall.deleted,
        configSchema: record.configSchema,
      );
    });
  }

  /// The `package_dir` of every live record: the directories to keep when
  /// sweeping. A removed record's package is no longer needed.
  Future<Set<String>> lyricsPluginPackageDirs() async {
    final query = selectOnly(lyricsPlugins)
      ..addColumns([lyricsPlugins.packageDir])
      ..where(lyricsPlugins.removedAt.isNull());
    return {
      for (final row in await query.get()) row.read(lyricsPlugins.packageDir)!,
    };
  }

  void _checkPluginId(String installId) {
    if (!isLyricsPluginId(installId)) {
      throw ArgumentError.value(
        installId,
        'installId',
        'must start with $lyricsPluginIdPrefix',
      );
    }
  }
}
