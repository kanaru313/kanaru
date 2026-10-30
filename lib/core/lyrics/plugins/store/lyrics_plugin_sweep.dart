import 'dart:io';

import 'package:logging/logging.dart';

import '../../../database/library_database.dart';
import '../../../database/lyrics_plugin_queries.dart';
import '../plugin_log_paths.dart';
import 'lyrics_plugin_dirs.dart';

final _log = Logger('lyrics_plugins');

/// Deletes package folders no live record points to, and the log files of
/// plugin ids with no live record (a removed plugin's logs go with it). It
/// must run before any install, update or uninstall, since a folder written
/// but not yet recorded looks unreferenced. Never throws.
Future<void> sweepLyricsPlugins(
  LibraryDatabase db,
  LyricsPluginDirs dirs,
  Directory logDir,
) async {
  try {
    final referenced = await db.lyricsPluginPackageDirs();
    final removedDirs = await dirs.sweep(referenced);
    final live = {
      for (final row in await db.watchLyricsPluginRecords().first)
        if (row.removedAt == null) row.installId,
    };
    var removedLogs = 0;
    for (final owner in await lyricsPluginLogOwners(logDir)) {
      if (!live.contains(owner)) {
        removedLogs += await deleteLyricsPluginLogs(logDir, owner);
      }
    }
    if (removedDirs > 0 || removedLogs > 0) {
      _log.info(
        'Plugin sweep removed $removedDirs folders and $removedLogs log files',
      );
    }
  } on Object catch (error) {
    _log.warning('Plugin sweep failed: ${error.runtimeType}');
  }
}
