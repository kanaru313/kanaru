import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import '../package/plugin_package.dart';
import 'plugin_config_schema_codec.dart';
import 'plugin_install_id.dart';

final _log = Logger('lyrics_plugins');

final _relativeShape = RegExp(r'^plugin-[a-z0-9]{12}/v\d+-\d+$');

/// The plugin package folders, `<data>/plugins/lyrics/<installId>/vN-T/`
/// (N the plugin version, T the write time). A folder is written whole
/// before the database points at it, and removed after the database stopped pointing at it, so the
/// database never names a missing or half-written package.
class LyricsPluginDirs {
  LyricsPluginDirs(String dataDirectory)
    : root = Directory('$dataDirectory/plugins/lyrics');

  final Directory root;

  /// Absolute path of the package folder [relative] (a `package_dir` value).
  /// Throws [ArgumentError] unless it has the shape `plugin-<12>/v<n>-<n>`,
  /// so no value from the database can leave the root.
  Directory resolve(String relative) {
    if (!_relativeShape.hasMatch(relative)) {
      throw ArgumentError.value(relative, 'relative', 'not a package folder');
    }
    return Directory('${root.path}/$relative');
  }

  /// A relative folder name for a new package of [installId] that is not
  /// taken yet. [now] is epoch milliseconds; a clash adds one until free.
  Future<String> freshPackageDir(String installId, int version, int now) async {
    var stamp = now;
    while (await resolve('$installId/v$version-$stamp').exists()) {
      stamp++;
    }
    return '$installId/v$version-$stamp';
  }

  /// Writes [package] into the new folder [relative]: `plugin.json`, the
  /// icon when kept, and `src/*.js`, each file flushed to disk. A failure
  /// removes what was written and rethrows.
  Future<void> writePackage(String relative, PluginPackage package) async {
    final dir = resolve(relative);
    try {
      await dir.create(recursive: true);
      final manifest = package.manifest;
      await _writeFile(
        File('${dir.path}/plugin.json'),
        utf8.encode(
          pluginManifestJson(
            apiVersion: manifest.apiVersion,
            name: manifest.name,
            version: manifest.version,
            hosts: manifest.hosts,
            author: manifest.author,
            description: manifest.description,
            searchScript: manifest.searchScript,
            lyricsScript: manifest.lyricsScript,
            config: manifest.config,
          ),
        ),
      );
      final icon = package.icon;
      if (icon != null) await _writeFile(File('${dir.path}/icon.png'), icon);
      await Directory('${dir.path}/src').create();
      for (final entry in package.files.entries) {
        if (entry.key.contains('/') || entry.key.contains('\\')) {
          throw ArgumentError.value(entry.key, 'name', 'not a plain file name');
        }
        await _writeFile(
          File('${dir.path}/src/${entry.key}'),
          utf8.encode(entry.value),
        );
      }
    } on Object {
      await deletePackageDir(relative);
      rethrow;
    }
  }

  /// Removes the package folder [relative] and its plugin folder when that
  /// is left empty. Never throws; a failure is logged and the sweep retries.
  Future<void> deletePackageDir(String relative) async {
    if (!_relativeShape.hasMatch(relative)) {
      _log.warning('Refused to delete a folder with an unexpected name');
      return;
    }
    await _delete(resolve(relative));
    final parent = resolve(relative).parent;
    try {
      if (parent.path != root.path &&
          await parent.exists() &&
          await parent.list().isEmpty) {
        await parent.delete();
      }
    } on FileSystemException {
      // Left for the sweep.
    }
  }

  /// Removes the whole folder tree of [installId]. Never throws.
  Future<bool> deleteInstallTree(String installId) async {
    if (!pluginInstallIdPattern.hasMatch(installId)) return false;
    return _delete(Directory('${root.path}/$installId'));
  }

  /// Removes every folder under the root that no entry of [referenced] names
  /// (relative `<installId>/v...` paths), and plugin folders left empty. A
  /// symbolic link is removed as a link, never followed. Returns the number
  /// of entries removed.
  Future<int> sweep(Set<String> referenced) async {
    var removed = 0;
    try {
      if (!await root.exists()) return 0;
      await for (final plugin in root.list(followLinks: false)) {
        // One unreadable entry is logged and skipped, not the whole sweep.
        try {
          removed += await _sweepEntry(plugin, referenced);
        } on FileSystemException catch (error) {
          _log.warning('Skipped a plugin folder: ${error.runtimeType}');
        }
      }
    } on FileSystemException catch (error) {
      _log.warning('Plugin folder sweep stopped: ${error.runtimeType}');
    }
    return removed;
  }

  Future<int> _sweepEntry(
    FileSystemEntity plugin,
    Set<String> referenced,
  ) async {
    if (plugin is! Directory) return await _delete(plugin) ? 1 : 0;
    final name = plugin.uri.pathSegments.where((s) => s.isNotEmpty).last;
    var removed = 0;
    var kept = 0;
    await for (final version in plugin.list(followLinks: false)) {
      final child = version.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (version is Directory && referenced.contains('$name/$child')) {
        kept++;
      } else if (await _delete(version)) {
        removed++;
      } else {
        kept++;
      }
    }
    if (kept == 0 && await _delete(plugin)) removed++;
    return removed;
  }

  Future<bool> _delete(FileSystemEntity entity) async {
    try {
      await entity.delete(recursive: true);
      return true;
    } on PathNotFoundException {
      return false;
    } on FileSystemException catch (error) {
      _log.warning('Could not delete a plugin folder: ${error.runtimeType}');
      return false;
    }
  }

  Future<void> _writeFile(File file, List<int> bytes) async {
    final handle = await file.open(mode: FileMode.write);
    try {
      await handle.writeFrom(bytes);
      await handle.flush();
    } finally {
      await handle.close();
    }
  }
}
