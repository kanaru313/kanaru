import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/library_startup.dart';
import '../../plugin_runtime/plugin_runtime_provider.dart';
import '../../secrets/secret_store_provider.dart';
import 'lyrics_plugins_controller.dart';
import 'package/plugin_package_reader.dart';
import 'plugin_log_paths.dart';
import 'plugin_needs_config_notices.dart';
import 'plugin_run_registry.dart';
import 'store/plugin_file_reader.dart';

export 'lyrics_plugins_controller.dart';

/// The controller; null while the library database or the data folder is
/// unavailable.
final lyricsPluginsControllerProvider = Provider<LyricsPluginsController?>((
  ref,
) {
  final db = ref.watch(libraryDatabaseProvider);
  final dataDir = ref.watch(lyricsPluginDataDirectoryProvider);
  if (db == null || dataDir == null) return null;
  return LyricsPluginsController(
    db: db,
    dataDirectory: dataDir,
    secretStore: () => ref.read(secretStoreProvider.future),
    reader: PluginPackageReader(
      TimeLimitedCheckRuntime(ref.watch(pluginRuntimeProvider)),
    ),
    runs: ref.watch(pluginRunRegistryProvider),
    // Read when called: the controller outlives no notice state.
    onNeedsConfig: (installId, name, kind) => ref
        .read(pluginNeedsConfigNoticesProvider.notifier)
        .report(installId, name, kind),
  );
});
