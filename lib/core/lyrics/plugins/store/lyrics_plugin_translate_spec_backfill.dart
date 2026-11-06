import 'dart:io';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import '../../../database/library_database.dart';
import '../package/plugin_manifest_parser.dart';
import '../package/plugin_package_limits.dart';
import '../package/plugin_package_problem.dart';
import 'lyrics_plugin_dirs.dart';
import 'plugin_translate_spec_codec.dart';

final _log = Logger('lyrics_plugins');

/// Fills `translate_spec` for live translation plugins that were installed
/// before the column existed, from the `plugin.json` of their current
/// package. A record whose manifest cannot be read keeps NULL (the translate
/// runner then reports it). Touches only rows still NULL and still pointing
/// at the folder that was read, and leaves `updated_at` alone. Never throws.
Future<void> backfillTranslateSpecs(
  LibraryDatabase db,
  LyricsPluginDirs dirs,
) async {
  try {
    final rows = await db
        .customSelect(
          'SELECT install_id, package_dir FROM lyrics_plugins '
          "WHERE removed_at IS NULL AND kind IN ('translate', 'ai-translate') "
          'AND translate_spec IS NULL',
        )
        .get();
    var filled = 0;
    for (final row in rows) {
      final installId = row.read<String>('install_id');
      final packageDir = row.read<String>('package_dir');
      final text = await _specText(dirs, packageDir);
      if (text == null) continue;
      try {
        final changed = await db.customUpdate(
          'UPDATE lyrics_plugins SET translate_spec = ? '
          'WHERE install_id = ? AND package_dir = ? AND translate_spec IS NULL',
          variables: [
            Variable.withString(text),
            Variable.withString(installId),
            Variable.withString(packageDir),
          ],
          updates: {db.lyricsPlugins},
          updateKind: UpdateKind.update,
        );
        filled += changed;
      } on Object catch (error) {
        _log.warning('Translate spec write failed: ${error.runtimeType}');
      }
    }
    if (filled > 0) _log.info('Filled the translate spec of $filled plugins');
  } on Object catch (error) {
    _log.warning('Translate spec backfill failed: ${error.runtimeType}');
  }
}

/// The encoded `translate` block of the package in [packageDir], or null when
/// the folder, the file or the block is unusable.
Future<String?> _specText(LyricsPluginDirs dirs, String packageDir) async {
  try {
    final file = File('${dirs.resolve(packageDir).path}/plugin.json');
    if (await file.length() > maxPluginManifestBytes) return null;
    final manifest = parsePluginManifest(await file.readAsBytes());
    final translate = manifest.translate;
    return translate == null ? null : encodePluginTranslateSpec(translate);
  } on ArgumentError {
    return null;
  } on FileSystemException {
    return null;
  } on PluginPackageProblem {
    return null;
  }
}
