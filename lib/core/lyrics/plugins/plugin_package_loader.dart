import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../plugin_runtime/plugin_runtime.dart';
import 'package/plugin_manifest_parser.dart';
import 'package/plugin_package_limits.dart';
import 'package/plugin_package_problem.dart';

/// The package of a plugin could not be read at run time (the folder is
/// missing, a file is unreadable or too large, the manifest is not valid).
/// [reason] names the problem and holds no path, so it is safe to log.
class PluginPackageUnreadable implements Exception {
  const PluginPackageUnreadable(this.reason);

  final String reason;

  @override
  String toString() => 'PluginPackageUnreadable($reason)';
}

/// The files of one installed package, ready to run.
class LoadedPluginPackage {
  const LoadedPluginPackage({
    required this.files,
    required this.searchScript,
    required this.lyricsScript,
  });

  /// Every file of `src/`; a script's `load()` reaches only these.
  final List<PluginSourceFile> files;

  /// Names of the entry files, from the manifest.
  final String searchScript;
  final String lyricsScript;
}

/// Reads package folders and keeps what it read, by folder. A folder is
/// written whole and never changed (an update writes a new one), so a cached
/// entry stays right for as long as its folder name is in the database.
/// Concurrent loads of one folder share one read; a failed read is not
/// cached, so the next run tries again.
class PluginPackageLoader {
  PluginPackageLoader({this.maxEntries = 16});

  /// Most folders kept; the oldest goes first. Old versions are never asked
  /// for again, so this only bounds memory.
  final int maxEntries;

  final _loads = <String, Future<LoadedPluginPackage>>{};

  /// The package in [dir], read once per [key] (the relative `package_dir`).
  Future<LoadedPluginPackage> load(String key, Directory dir) {
    final cached = _loads[key];
    if (cached != null) return cached;
    final load = _read(dir);
    _loads[key] = load;
    while (_loads.length > maxEntries) {
      _loads.remove(_loads.keys.first);
    }
    // A failed read must not stay cached.
    load.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_loads[key], load)) _loads.remove(key);
      },
    );
    return load;
  }

  Future<LoadedPluginPackage> _read(Directory dir) async {
    try {
      final manifest = parsePluginManifest(
        await _readBytes(
          File('${dir.path}/plugin.json'),
          maxPluginManifestBytes,
        ),
      );
      final files = <PluginSourceFile>[];
      var total = 0;
      await for (final entity in Directory(
        '${dir.path}/src',
      ).list(followLinks: false)) {
        if (entity is! File) continue;
        final bytes = await _readBytes(entity, maxPluginScriptBytes);
        total += bytes.length;
        if (total > maxPluginUnpackedBytes) {
          throw const PluginPackageUnreadable('package too large');
        }
        files.add(
          PluginSourceFile(
            name: entity.uri.pathSegments.last,
            code: utf8.decode(bytes),
          ),
        );
      }
      for (final script in [manifest.searchScript, manifest.lyricsScript]) {
        if (!files.any((f) => f.name == script)) {
          throw const PluginPackageUnreadable('a script file is missing');
        }
      }
      return LoadedPluginPackage(
        files: List.unmodifiable(files),
        searchScript: manifest.searchScript,
        lyricsScript: manifest.lyricsScript,
      );
    } on PluginPackageUnreadable {
      rethrow;
    } on FileSystemException {
      throw const PluginPackageUnreadable('package files cannot be read');
    } on FormatException {
      throw const PluginPackageUnreadable('a script is not valid UTF-8');
    } on PluginPackageProblem {
      throw const PluginPackageUnreadable('plugin.json is not valid');
    }
  }
}

Future<Uint8List> _readBytes(File file, int limit) async {
  if (await file.length() > limit) {
    throw const PluginPackageUnreadable('a package file is too large');
  }
  return file.readAsBytes();
}
