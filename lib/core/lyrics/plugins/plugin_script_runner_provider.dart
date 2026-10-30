import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/library_startup.dart';
import '../../plugin_runtime/plugin_runtime_provider.dart';
import 'lyrics_plugins_provider.dart';
import 'plugin_log_paths.dart';
import 'plugin_run_log.dart';
import 'plugin_run_registry.dart';
import 'plugin_script_runner.dart';
import 'store/lyrics_plugin_dirs.dart';

/// The one runner of plugin scripts: its package cache is shared by every
/// plugin provider. `null` while the library database or the data folder is
/// unavailable (a plugin source is then not registered).
final pluginScriptRunnerProvider = Provider<PluginScriptRunner?>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  final dataDir = ref.watch(lyricsPluginDataDirectoryProvider);
  final logDir = ref.watch(lyricsPluginLogDirProvider);
  if (db == null || dataDir == null || logDir == null) return null;
  return PluginScriptRunner(
    db: db,
    runtime: ref.watch(pluginRuntimeProvider),
    runs: ref.watch(pluginRunRegistryProvider),
    runLog: PluginRunLog(logDir),
    dirs: LyricsPluginDirs(dataDir),
    // The controller reads the config and the secrets; read lazily so a
    // rebuild of the controller does not rebuild the runner.
    loadConfig: (installId) async =>
        await ref
            .read(lyricsPluginsControllerProvider)
            ?.configForRun(installId) ??
        const {},
  );
});
