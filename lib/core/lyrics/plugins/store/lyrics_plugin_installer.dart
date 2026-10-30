import 'dart:math';

import 'package:logging/logging.dart';

import '../../../database/library_database.dart';
import '../../../database/lyrics_plugin_queries.dart';
import '../lyrics_plugin_record.dart';
import '../package/plugin_package.dart';
import '../plugin_run_registry.dart';
import 'lyrics_plugin_config_store.dart';
import 'lyrics_plugin_dirs.dart';
import 'plugin_config_schema_codec.dart';
import 'plugin_install_id.dart';
import 'plugin_install_outcome.dart';

final _log = Logger('lyrics_plugins');

/// Where an installed package came from.
class PluginInstallSource {
  /// A zip the user picked; [name] is its file name.
  const PluginInstallSource.file(this.name)
    : kind = LyricsPluginSourceKind.file,
      repoUrl = null,
      repoSlug = null;

  /// Plugin [slug] of the repository at [url]; [name] is the repository name.
  const PluginInstallSource.repo({
    required this.name,
    required String this.repoUrl,
    required String this.repoSlug,
  }) : kind = LyricsPluginSourceKind.repo;

  /// The source an installed [record] already has.
  PluginInstallSource.of(LyricsPluginRecord record)
    : kind = record.sourceKind,
      name = record.sourceName,
      repoUrl = record.repoUrl,
      repoSlug = record.repoSlug;

  final LyricsPluginSourceKind kind;
  final String name;
  final String? repoUrl;
  final String? repoSlug;
}

/// Installs and updates plugin packages: files first, then the database
/// switch, so the database never names a package that is not fully on disk.
/// Callers run it through the controller's serial queue.
class LyricsPluginInstaller {
  LyricsPluginInstaller({
    required this._db,
    required this._dirs,
    required this._config,
    required this._runs,
    DateTime Function()? clock,
    this._random,
  }) : _clock = clock ?? DateTime.now;

  final LibraryDatabase _db;
  final LyricsPluginDirs _dirs;
  final LyricsPluginConfigStore _config;
  final PluginRunRegistry _runs;
  final DateTime Function() _clock;
  final Random? _random;

  /// Installs [package] as a new plugin: enabled, last in the order. A repo
  /// plugin whose (url, slug) has a removed record revives it under the same
  /// id (old secrets are deleted, config and storage start empty; saved
  /// lyrics, pins and rejects show again). One whose record is live is
  /// updated instead. A database failure removes the new folder and rethrows.
  /// Throws [PluginSecretsUnavailableException] when a revive cannot delete
  /// the old secrets (nothing else changed), and
  /// [PluginUpdateRefusedException] as [update] does.
  Future<LyricsPluginRecord> install(
    PluginPackage package,
    PluginInstallSource source,
  ) async {
    final url = source.repoUrl;
    final slug = source.repoSlug;
    final existing = url == null || slug == null
        ? null
        : await _db.lyricsPluginByRepo(url, slug);
    if (existing != null && existing.removedAt == null) {
      final updated = await update(existing.installId, package);
      return updated ??
          (throw StateError('Plugin record vanished during install'));
    }
    // Revive: nothing of the old install may come back, so its secrets go
    // first; if the store cannot delete them, change nothing.
    if (existing != null &&
        !await _config.deleteSecretsOf(
          existing.installId,
          LyricsPluginRecord.fromRow(existing).config,
        )) {
      throw const PluginSecretsUnavailableException();
    }
    final now = _now();
    final installId =
        existing?.installId ?? await uniquePluginInstallId(_db, _random);
    final relative = await _dirs.freshPackageDir(
      installId,
      package.manifest.version,
      now,
    );
    await _dirs.writePackage(relative, package);
    try {
      final spec = _spec(package, relative, source);
      if (existing != null) {
        if (await _db.reviveLyricsPlugin(installId, spec, now: now) == null) {
          throw StateError('Plugin record vanished during install');
        }
      } else {
        await _db.insertLyricsPlugin(installId, spec, now: now);
      }
    } on Object {
      await _dirs.deletePackageDir(relative);
      rethrow;
    }
    await _enable(installId);
    return LyricsPluginRecord.fromRow((await _db.lyricsPluginById(installId))!);
  }

  /// Replaces the package of the live repo plugin [installId] with [package]:
  /// new runs of the plugin are refused and running ones cancelled, the new
  /// folder is written, the database switches to it in one transaction, then
  /// the old folder goes. Config, storage, on/off and position stay; config
  /// values follow the new form. Returns null when the plugin is missing or
  /// removed. Throws [PluginUpdateRefusedException] for a file plugin or a
  /// package with a lower version than installed (equal is allowed).
  Future<LyricsPluginRecord?> update(
    String installId,
    PluginPackage package,
  ) async {
    final row = await _db.lyricsPluginById(installId);
    if (row == null || row.removedAt != null) return null;
    final old = LyricsPluginRecord.fromRow(row);
    if (old.sourceKind != LyricsPluginSourceKind.repo) {
      throw const PluginUpdateRefusedException(PluginUpdateRefusal.notFromRepo);
    }
    if (package.manifest.version < old.version) {
      throw const PluginUpdateRefusedException(
        PluginUpdateRefusal.olderVersion,
      );
    }
    _runs.block(installId);
    try {
      return await _switch(old, package);
    } finally {
      _runs.unblock(installId);
    }
  }

  Future<LyricsPluginRecord?> _switch(
    LyricsPluginRecord old,
    PluginPackage package,
  ) async {
    final installId = old.installId;
    await _runs.cancelAll(installId);
    final now = _now();
    final relative = await _dirs.freshPackageDir(
      installId,
      package.manifest.version,
      now,
    );
    await _dirs.writePackage(relative, package);
    try {
      final spec = _spec(package, relative, PluginInstallSource.of(old));
      if (await _db.switchLyricsPluginPackage(installId, spec, now: now) ==
          null) {
        await _dirs.deletePackageDir(relative);
        return null;
      }
    } on Object {
      await _dirs.deletePackageDir(relative);
      rethrow;
    }
    await _dirs.deletePackageDir(old.packageDir);
    try {
      await _config.adaptToForm(installId, old.config, package.manifest.config);
    } on Object catch (error) {
      _log.warning('Config move after update failed: ${error.runtimeType}');
    }
    return LyricsPluginRecord.fromRow((await _db.lyricsPluginById(installId))!);
  }

  Future<void> _enable(String installId) async {
    try {
      await _db.setLyricsSourceEnabled(installId, true);
    } on Object catch (error) {
      // A source with no preference row is on and last anyway.
      _log.warning('Could not write the source order: ${error.runtimeType}');
    }
  }

  int _now() => _clock().millisecondsSinceEpoch;

  LyricsPluginSpec _spec(
    PluginPackage package,
    String relative,
    PluginInstallSource source,
  ) {
    final manifest = package.manifest;
    return LyricsPluginSpec(
      name: manifest.name,
      author: manifest.author.isEmpty ? null : manifest.author,
      description: manifest.description.isEmpty ? null : manifest.description,
      version: manifest.version,
      apiVersion: manifest.apiVersion,
      hosts: manifest.hosts,
      configSchema: encodePluginConfigSchema(manifest.config),
      packageDir: relative,
      sourceKind: source.kind,
      sourceName: source.name,
      repoUrl: source.repoUrl,
      repoSlug: source.repoSlug,
    );
  }
}
