import 'dart:io';

import 'package:logging/logging.dart';

import '../../../database/library_database.dart';
import '../../../database/lyrics_plugin_queries.dart';
import '../plugin_log_paths.dart';
import '../plugin_run_registry.dart';
import 'lyrics_plugin_config_store.dart';
import 'lyrics_plugin_dirs.dart';
import 'plugin_config_schema_codec.dart';

final _log = Logger('lyrics_plugins');

/// Removes a plugin: in-flight runs are cancelled first, the database change
/// comes next (it decides what is kept, see `uninstallLyricsPlugin`), and the
/// secrets, folders and log files follow. A failure after the database change
/// is logged and never undoes it; the startup sweep retries folders and logs.
class LyricsPluginUninstaller {
  LyricsPluginUninstaller({
    required this._db,
    required this._dirs,
    required this._config,
    required this._runs,
    required this._logDir,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LibraryDatabase _db;
  final LyricsPluginDirs _dirs;
  final LyricsPluginConfigStore _config;
  final PluginRunRegistry _runs;
  final Directory _logDir;
  final DateTime Function() _clock;

  /// Uninstalls [installId]. A missing or already removed record is left as
  /// it is and its secrets and folders are not touched again.
  Future<LyricsPluginUninstall> uninstall(String installId) async {
    // New runs are refused while the record changes; afterwards the record is
    // removed or gone, which a starting run checks.
    _runs.block(installId);
    try {
      await _runs.cancelAll(installId);
      return await _remove(installId);
    } finally {
      _runs.unblock(installId);
    }
  }

  Future<LyricsPluginUninstall> _remove(String installId) async {
    final result = await _db.uninstallLyricsPlugin(
      installId,
      now: _clock().millisecondsSinceEpoch,
    );
    if (result.outcome == LyricsPluginUninstall.missing ||
        result.outcome == LyricsPluginUninstall.alreadyRemoved) {
      return result.outcome;
    }
    final schema = decodePluginConfigSchema(result.configSchema ?? '[]');
    await _config.deleteSecretsOf(installId, schema);
    await _dirs.deleteInstallTree(installId);
    await deleteLyricsPluginLogs(
      _logDir,
      installId,
      onFailure: () => _log.warning('Could not delete a plugin log file'),
    );
    return result.outcome;
  }
}
