import 'dart:convert';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../../../plugin_runtime/plugin_runtime.dart';
import 'plugin_manifest_parser.dart';
import 'plugin_package.dart';
import 'plugin_package_problem.dart';
import 'plugin_zip_reader.dart';

export 'plugin_package.dart';
export 'plugin_package_problem.dart';

final _log = Logger('plugin_package');

/// Reads a plugin zip: safe unpack in memory, manifest checks, and a syntax
/// check of every script. Nothing is written to disk and no script runs.
class PluginPackageReader {
  const PluginPackageReader(this._runtime);

  /// Only [PluginRuntime.check] is used.
  final PluginRuntime _runtime;

  /// Returns the whole package or the first problem found; never a part.
  Future<PluginPackageResult> read(Uint8List zipBytes) async {
    try {
      return PluginPackageAccepted(await _read(zipBytes));
    } on PluginPackageProblem catch (problem) {
      return PluginPackageRejected(problem);
    }
  }

  Future<PluginPackage> _read(Uint8List zipBytes) async {
    final contents = readPluginZip(zipBytes);
    final manifest = parsePluginManifest(contents.manifest);
    final files = _decodeScripts(contents.scripts);
    for (final name in [manifest.searchScript, manifest.lyricsScript]) {
      if (!files.containsKey(name)) {
        throw PluginPackageProblem(
          PluginPackageProblemKind.missingScript,
          detail: name,
        );
      }
    }
    await _checkSyntax(files);
    final iconProblem = contents.iconProblem;
    if (iconProblem != null) {
      // Only the reason is logged: the install goes on without the icon.
      _log.info('plugin icon dropped: $iconProblem');
    }
    return PluginPackage(
      manifest: manifest,
      files: Map.unmodifiable(files),
      icon: contents.icon,
    );
  }

  /// UTF-8 decode, BOM stripped; a script that is not UTF-8 is refused.
  Map<String, String> _decodeScripts(Map<String, Uint8List> scripts) {
    final names = scripts.keys.toList()..sort();
    return {for (final name in names) name: _decode(name, scripts[name]!)};
  }

  String _decode(String name, Uint8List bytes) {
    try {
      final text = utf8.decode(bytes);
      return text.startsWith('﻿') ? text.substring(1) : text;
    } on FormatException {
      throw PluginPackageProblem(
        PluginPackageProblemKind.scriptError,
        detail: name,
        message: 'not valid UTF-8',
      );
    }
  }

  Future<void> _checkSyntax(Map<String, String> files) async {
    for (final entry in files.entries) {
      final PluginScriptProblem? problem;
      try {
        problem = await _runtime.check(entry.key, entry.value);
      } on Object {
        // The runtime throws when it cannot check at all; accepting would
        // claim the script is valid without looking.
        throw const PluginPackageProblem(
          PluginPackageProblemKind.checkUnavailable,
        );
      }
      if (problem != null) {
        throw PluginPackageProblem(
          PluginPackageProblemKind.scriptError,
          detail: entry.key,
          line: problem.line,
          message: problem.message,
        );
      }
    }
  }
}
