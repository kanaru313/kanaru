import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../../database/library_database.dart';
import '../../database/lyrics_plugin_queries.dart';
import '../../plugin_runtime/plugin_runtime.dart';
import '../../secrets/secret_store_provider.dart' show ResolvedSecretStore;
import 'lyrics_plugin_record.dart';
import 'package/plugin_package_reader.dart';
import 'plugin_log_paths.dart';
import 'plugin_run_registry.dart';
import 'store/lyrics_plugin_config_store.dart';
import 'store/lyrics_plugin_dirs.dart';
import 'store/lyrics_plugin_installer.dart';
import 'store/lyrics_plugin_sweep.dart';
import 'store/lyrics_plugin_translate_spec_backfill.dart';
import 'store/lyrics_plugin_uninstaller.dart';
import 'store/plugin_config_required.dart';
import 'store/plugin_config_schema_codec.dart';
import 'store/plugin_file_reader.dart';
import 'store/plugin_install_outcome.dart';
import 'store/serial_queue.dart';

export '../../database/lyrics_plugin_spec.dart'
    show LyricsPluginUninstall, LyricsPluginWrite;

export 'lyrics_plugin_record.dart';
export 'store/lyrics_plugin_config_store.dart' show PluginConfigWrite;
export 'store/lyrics_plugin_installer.dart' show PluginInstallSource;
export 'store/plugin_install_outcome.dart';

final _log = Logger('lyrics_plugins');

/// The operations the UI calls on lyrics plugins. Every change goes through
/// one serial queue whose first job is the startup sweep, so an install, an
/// undo, an update and an uninstall never interleave. No UI text lives here.
class LyricsPluginsController {
  LyricsPluginsController({
    required this._db,
    required String dataDirectory,
    required this._secretStore,
    required this._reader,
    required PluginRunRegistry runs,
    this.onNeedsConfig,
    DateTime Function()? clock,
    Random? random,
  }) : _dirs = LyricsPluginDirs(dataDirectory),
       _logDir = lyricsPluginLogDirOf(dataDirectory) {
    _config = LyricsPluginConfigStore(_db, _secretStore);
    _installer = LyricsPluginInstaller(
      db: _db,
      dirs: _dirs,
      config: _config,
      runs: runs,
      clock: clock,
      random: random,
    );
    _uninstaller = LyricsPluginUninstaller(
      db: _db,
      dirs: _dirs,
      config: _config,
      runs: runs,
      logDir: _logDir,
      clock: clock,
    );
    _ready = _queue.run(() async {
      await sweepLyricsPlugins(_db, _dirs, _logDir);
      await backfillTranslateSpecs(_db, _dirs);
    });
  }

  final LibraryDatabase _db;
  final PluginPackageReader _reader;
  final Future<ResolvedSecretStore> Function() _secretStore;
  final LyricsPluginDirs _dirs;
  final Directory _logDir;
  final SerialQueue _queue = SerialQueue();
  late final LyricsPluginConfigStore _config;
  late final LyricsPluginInstaller _installer;
  late final LyricsPluginUninstaller _uninstaller;
  late final Future<void> _ready;

  /// Called after a plugin was switched on while a required config field is
  /// empty (the plugin stays on). Never called for switching off or for a
  /// write that did not happen.
  final void Function(String installId, String name, PluginKind? kind)?
  onNeedsConfig;

  /// Completes when the startup sweep and the translate spec backfill have
  /// finished.
  Future<void> get ready => _ready;

  /// Every record, removed ones included, oldest install first.
  Stream<List<LyricsPluginRecord>> watchRecords() => _db
      .watchLyricsPluginRecords()
      .map((rows) => [for (final row in rows) LyricsPluginRecord.fromRow(row)]);

  /// Installs the zip at [path] as a new plugin (the file's base name is the
  /// source). The read is done before the queue, so a slow file blocks no
  /// other operation.
  Future<PluginInstallOutcome> installFromFile(String path) async {
    final Uint8List bytes;
    try {
      bytes = await readPluginFile(path);
    } on PluginPackageProblem catch (problem) {
      return PluginInstallRejected(problem);
    }
    final name = path.split(Platform.pathSeparator).last;
    return installFromBytes(bytes, PluginInstallSource.file(name));
  }

  /// Checks [zipBytes] and installs them (a repo download, or a file read
  /// elsewhere).
  Future<PluginInstallOutcome> installFromBytes(
    Uint8List zipBytes,
    PluginInstallSource source,
  ) => _checked(zipBytes, (package) async {
    final record = await installPackage(package, source);
    return PluginInstalled(record);
  });

  /// Installs a checked package. See [LyricsPluginInstaller.install]; it
  /// throws [PluginSecretsUnavailableException] and
  /// [PluginUpdateRefusedException], which the `...FromBytes` methods turn
  /// into outcomes.
  Future<LyricsPluginRecord> installPackage(
    PluginPackage package,
    PluginInstallSource source,
  ) => _queue.run(() => _installer.install(package, source));

  /// Replaces the package of [installId] with the one in [zipBytes].
  Future<PluginInstallOutcome> updateFromBytes(
    String installId,
    Uint8List zipBytes,
  ) => _checked(zipBytes, (package) async {
    final record = await updatePackage(installId, package);
    return record == null ? const PluginInstallGone() : PluginInstalled(record);
  });

  /// Updates a live repo plugin; null when it is missing or removed. Throws
  /// [PluginUpdateRefusedException] (see [LyricsPluginInstaller.update]).
  Future<LyricsPluginRecord?> updatePackage(
    String installId,
    PluginPackage package,
  ) => _queue.run(() => _installer.update(installId, package));

  Future<PluginInstallOutcome> _checked(
    Uint8List zipBytes,
    Future<PluginInstallOutcome> Function(PluginPackage package) apply,
  ) async {
    final result = await _reader.read(zipBytes);
    switch (result) {
      case PluginPackageRejected(:final problem):
        return PluginInstallRejected(problem);
      case PluginPackageAccepted(:final package):
        try {
          return await apply(package);
        } on PluginUpdateRefusedException catch (refused) {
          return PluginInstallRefused(refused.reason);
        } on PluginSecretsUnavailableException {
          return const PluginInstallSecretsUnavailable();
        }
    }
  }

  /// Uninstalls [installId]; see [LyricsPluginUninstaller.uninstall].
  Future<LyricsPluginUninstall> uninstall(String installId) =>
      _queue.run(() => _uninstaller.uninstall(installId));

  /// Undo of an install: the same as [uninstall]. With nothing saved from the
  /// plugin the record is deleted outright.
  Future<LyricsPluginUninstall> undoInstall(String installId) =>
      uninstall(installId);

  Future<LyricsPluginWrite> setEnabled(String installId, bool enabled) async {
    final result = await _queue.run(
      () => _db.setLyricsSourceEnabled(installId, enabled),
    );
    if (enabled && result == LyricsPluginWrite.written) {
      // The notice is a courtesy: the keyring read must not delay the switch.
      unawaited(_reportIfNeedsConfig(installId));
    }
    return result;
  }

  /// Asks [onNeedsConfig] to report [installId] when a required field is
  /// empty. Runs outside the queue; the notice is a courtesy, so a failure is
  /// logged and swallowed.
  Future<void> _reportIfNeedsConfig(String installId) async {
    final callback = onNeedsConfig;
    if (callback == null) return;
    try {
      final row = await _db.lyricsPluginById(installId);
      if (row == null || row.removedAt != null) return;
      if (!await needsConfig(installId)) return;
      // Switched off again while the check ran: nothing to configure.
      if (!await _db.lyricsSourceIsOn(installId)) return;
      callback(installId, row.name, PluginKind.fromValue(row.kind));
    } on Object catch (error) {
      _log.fine('Could not check the plugin settings: ${error.runtimeType}');
    }
  }

  /// Puts [ids] (plugin ids) first, in order; returns the ids
  /// that were written and the ones skipped (removed or unknown plugins).
  Future<({List<String> written, List<String> skipped})> reorder(
    List<String> ids,
  ) => _queue.run(() => _db.reorderLyricsSources(ids));

  /// Empties the plugin's localStorage.
  Future<LyricsPluginWrite> clearStorage(String installId) =>
      _queue.run(() async {
        final row = await _db.lyricsPluginById(installId);
        if (row == null) return LyricsPluginWrite.skipped;
        return _db.setLyricsPluginStorage(
          installId,
          const {},
          expectedUpdatedAt: row.updatedAt,
        );
      });

  /// Deletes the lyrics this plugin saved (pins and rejects stay). Returns
  /// the rows removed.
  Future<int> clearSavedLyrics(String installId) =>
      _queue.run(() => _db.clearLyricsPluginSavedLyrics(installId));

  /// Sets one config value; a secret goes to the secret store only.
  Future<PluginConfigWrite> setConfigValue(
    String installId,
    String key,
    Object? value,
  ) => _queue.run(() => _config.setValue(installId, key, value));

  /// Adds a model to the plugin's `custom` model select and selects it; see
  /// [LyricsPluginConfigStore.addCustomModel].
  Future<PluginConfigWrite> addCustomModel(
    String installId,
    String value, {
    String? subtitle,
  }) => _queue.run(
    () => _config.addCustomModel(installId, value, subtitle: subtitle),
  );

  /// Removes a model the user added; see
  /// [LyricsPluginConfigStore.removeCustomModel]. When no model is left to
  /// select, a plugin that is on and now lacks a required value is reported.
  Future<PluginConfigWrite> removeCustomModel(
    String installId,
    String value,
  ) async {
    final result = await _queue.run(
      () => _config.removeCustomModel(installId, value),
    );
    if (result == PluginConfigWrite.written) {
      unawaited(_reportIfNeedsConfig(installId));
    }
    return result;
  }

  /// What a script run reads as `localConfig`, secrets included.
  Future<PluginConfigMap> configForRun(String installId) =>
      _config.configForRun(installId);

  /// Whether a required field of [installId] has no value, so a run would be
  /// blocked. False for a missing or removed plugin.
  Future<bool> needsConfig(String installId) async {
    final row = await _db.lyricsPluginById(installId);
    if (row == null || row.removedAt != null) return false;
    return missingRequiredConfig(
      decodePluginConfigSchema(row.configSchema),
      await configForRun(installId),
    ).isNotEmpty;
  }

  /// The non-secret values as stored, for the config form.
  Future<Map<String, Object?>> storedConfig(String installId) =>
      _config.storedValues(installId);

  /// Whether the secret [key] has a value, for the config form.
  Future<bool> hasSecret(String installId, String key) =>
      _config.hasSecret(installId, key);

  /// Whether secrets are kept in a plain file or in memory because no system
  /// keyring exists; the UI warns about it.
  Future<bool> secretsUsingFallback() async {
    try {
      return (await _secretStore()).usingFallback;
    } on Object catch (error) {
      _log.warning('Secret store not resolved: ${error.runtimeType}');
      return false;
    }
  }
}
