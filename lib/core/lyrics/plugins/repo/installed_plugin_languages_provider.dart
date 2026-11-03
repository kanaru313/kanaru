import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../package/plugin_languages.dart';
import '../package/plugin_package_limits.dart';
import '../plugin_log_paths.dart';
import '../store/lyrics_plugin_dirs.dart';
import 'lyrics_plugin_repos_provider.dart';

final _log = Logger('lyrics_plugin_repos');

/// The language keys (see `parsePluginLanguages`) of the installed package in
/// [packageDir], read from its `plugin.json` `metadata.languages`. Empty
/// (global) when the file is missing, unreadable, too large, not JSON, or has
/// none; other errors are logged and rethrown.
Future<List<String>> readInstalledPluginLanguages(Directory packageDir) async {
  try {
    final file = File('${packageDir.path}/plugin.json');
    if (await file.length() > maxPluginManifestBytes) return const [];
    var text = await file.readAsString();
    if (text.startsWith('﻿')) text = text.substring(1);
    final json = jsonDecode(text);
    if (json is! Map) return const [];
    final metadata = json['metadata'];
    if (metadata is! Map) return const [];
    return parsePluginLanguages(metadata['languages']);
  } on PathNotFoundException {
    _log.fine('No plugin.json in ${packageDir.path}');
    return const [];
  } on FileSystemException catch (error) {
    _log.warning(
      'Cannot read plugin.json in ${packageDir.path}: ${error.message}',
    );
    return const [];
  } on FormatException {
    // No message: it can quote file content.
    _log.warning('plugin.json in ${packageDir.path} is not JSON');
    return const [];
  } on Object catch (error, stackTrace) {
    _log.severe(
      'Reading the languages of ${packageDir.path} failed',
      error,
      stackTrace,
    );
    rethrow;
  }
}

/// Languages of the installed packages that declare any, by install id. Lets
/// the store filter plugins that have no catalog entry (installed from a
/// file, or from a repository since removed). Empty without a data folder, so
/// widget tests stay off the disk.
final installedPluginLanguagesProvider =
    FutureProvider.autoDispose<Map<String, List<String>>>(
      (ref) async {
        final dataDir = ref.watch(lyricsPluginDataDirectoryProvider);
        if (dataDir == null) return const {};
        final records = ref.watch(
          pluginStoreRawInputProvider.select((v) => v.value?.records),
        );
        if (records == null) return const {};
        final dirs = LyricsPluginDirs(dataDir);
        final reads = <String, Future<List<String>>>{};
        for (final record in records) {
          if (record.isRemoved) continue;
          try {
            reads[record.installId] = readInstalledPluginLanguages(
              dirs.resolve(record.packageDir),
            );
          } on ArgumentError {
            continue;
          }
        }
        final out = <String, List<String>>{};
        for (final e in reads.entries) {
          final languages = await e.value;
          if (languages.isNotEmpty) out[e.key] = languages;
        }
        return out;
      },
      // Expected read failures are handled; a retry would only re-log.
      retry: (_, _) => null,
    );
