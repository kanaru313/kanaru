import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../paths/app_directories.dart';
import 'store/plugin_install_id.dart';

/// The app's data directory (`resolveDataDirectory` on the real
/// environment), so the plugin controller works in the app without extra
/// wiring. Under `flutter test` (`FLUTTER_TEST=true`) it is `null` instead of
/// the user's real folder: a test that needs the controller must override
/// this provider with a temp folder, so no test can sweep real plugin data.
final lyricsPluginDataDirectoryProvider = Provider<String?>((ref) {
  final env = Platform.environment;
  if (env['FLUTTER_TEST'] == 'true') return null;
  return resolveDataDirectory(env);
});

/// Folder of the per-plugin log files: `<data>/plugin-logs`.
final lyricsPluginLogDirProvider = Provider<Directory?>((ref) {
  final data = ref.watch(lyricsPluginDataDirectoryProvider);
  return data == null ? null : lyricsPluginLogDirOf(data);
});

/// Folder of the per-plugin log files under the data folder [dataDirectory]:
/// `<data>/plugin-logs`. The only place that builds this path.
Directory lyricsPluginLogDirOf(String dataDirectory) =>
    Directory('$dataDirectory/plugin-logs');

/// The current log file of [installId] in [logDir], or null when the id is
/// not a plugin id (so it can never name another file).
File? lyricsPluginLogFile(Directory logDir, String installId) =>
    pluginInstallIdPattern.hasMatch(installId)
    ? File('${logDir.path}/$installId.jsonl')
    : null;

/// The plugin id a log file name belongs to (`<id>.jsonl` or
/// `<id>.jsonl.<n>`), or null for any other name.
String? _logOwner(String fileName) {
  final cut = fileName.indexOf('.jsonl');
  if (cut < 0) return null;
  final rest = fileName.substring(cut + '.jsonl'.length);
  if (rest.isNotEmpty && !rest.startsWith('.')) return null;
  final id = fileName.substring(0, cut);
  return pluginInstallIdPattern.hasMatch(id) ? id : null;
}

/// Ids that have at least one log file in [logDir]; empty when it is absent.
Future<Set<String>> lyricsPluginLogOwners(Directory logDir) async {
  final owners = <String>{};
  try {
    await for (final entity in logDir.list(followLinks: false)) {
      final owner = _logOwner(entity.uri.pathSegments.last);
      if (owner != null) owners.add(owner);
    }
  } on FileSystemException {
    // No folder yet, or unreadable: nothing to report.
  }
  return owners;
}

/// Deletes `<installId>.jsonl*` from [logDir]. Returns how many files were
/// removed; a file that cannot be deleted is skipped (the next sweep retries)
/// and reported to [onFailure].
Future<int> deleteLyricsPluginLogs(
  Directory logDir,
  String installId, {
  void Function()? onFailure,
}) async {
  if (!pluginInstallIdPattern.hasMatch(installId)) return 0;
  var removed = 0;
  try {
    await for (final entity in logDir.list(followLinks: false)) {
      if (_logOwner(entity.uri.pathSegments.last) != installId) continue;
      try {
        await entity.delete();
        removed++;
      } on FileSystemException {
        onFailure?.call();
      }
    }
  } on FileSystemException {
    // No folder: nothing to delete.
  }
  return removed;
}
