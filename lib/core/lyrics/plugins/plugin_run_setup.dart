import '../../database/library_database.dart';
import '../../database/lyrics_plugin_queries.dart';
import 'plugin_package_loader.dart';
import 'store/lyrics_plugin_dirs.dart';

/// The settings or the stored map of a plugin could not be read (a database
/// or secret store failure). [reason] holds no value, so it is safe to log.
class PluginRunSetupException implements Exception {
  const PluginRunSetupException(this.reason);

  final String reason;

  @override
  String toString() => 'PluginRunSetupException($reason)';
}

/// Everything a run needs besides the input: the package, the config
/// (secrets included) and the stored map as JSON.
class PluginRunSetup {
  const PluginRunSetup(this.package, this.config, this.storageJson);

  final LoadedPluginPackage package;
  final Map<String, String> config;
  final String storageJson;
}

/// Loads what the run of [record] needs. Throws [PluginPackageUnreadable]
/// (also for a malformed folder name) or [PluginRunSetupException]; nothing
/// else escapes.
Future<PluginRunSetup> loadPluginRunSetup({
  required LibraryDatabase db,
  required PluginPackageLoader packages,
  required LyricsPluginDirs dirs,
  required Future<Map<String, String>> Function(String installId) loadConfig,
  required LyricsPluginRow record,
}) async {
  final LoadedPluginPackage package;
  try {
    package = await packages.load(
      record.packageDir,
      dirs.resolve(record.packageDir),
    );
  } on ArgumentError {
    throw const PluginPackageUnreadable('the package folder name is not valid');
  }
  try {
    final config = await loadConfig(record.installId);
    final data = await db.lyricsPluginDataFor(record.installId);
    return PluginRunSetup(package, config, data?.storage ?? '');
  } on Object {
    // The error text may carry a value; only the fact is kept.
    throw const PluginRunSetupException(
      'settings or storage could not be read',
    );
  }
}
