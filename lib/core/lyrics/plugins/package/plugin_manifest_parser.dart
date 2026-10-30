import 'dart:convert';
import 'dart:typed_data';

import '../../online/lyrics_provider_registry.dart';
import 'plugin_config_parser.dart';
import 'plugin_manifest.dart';
import 'plugin_package_problem.dart';
import 'plugin_text_clean.dart';

/// The newest `metadata.apiVersion` this app understands.
const supportedPluginApiVersion = 1;

final _scriptName = RegExp(r'^[A-Za-z0-9_.-]+$');

PluginPackageProblem _invalid(String field) => PluginPackageProblem(
  PluginPackageProblemKind.invalidManifest,
  detail: field,
);

/// Parses and checks `plugin.json`. Unknown fields are ignored. Throws
/// [PluginPackageProblem]. Whether the script files exist is checked by the
/// caller against the unpacked `src/` names.
PluginManifest parsePluginManifest(Uint8List bytes) {
  final Object? json;
  try {
    // BOM-tolerant: a leading U+FEFF is dropped before parsing.
    var text = utf8.decode(bytes);
    if (text.startsWith('﻿')) text = text.substring(1);
    json = jsonDecode(text);
  } on FormatException {
    throw _invalid('plugin.json');
  }
  if (json is! Map<String, dynamic>) throw _invalid('plugin.json');

  final metadata = json['metadata'];
  if (metadata is! Map<String, dynamic>) throw _invalid('metadata');

  final apiVersion = metadata['apiVersion'];
  if (apiVersion is! int || apiVersion < 1) {
    throw _invalid('metadata.apiVersion');
  }
  if (apiVersion > supportedPluginApiVersion) {
    throw PluginPackageProblem(
      PluginPackageProblemKind.needsNewerApp,
      detail: '$apiVersion',
    );
  }
  if (metadata['type'] != 'lyrics') {
    throw PluginPackageProblem(
      PluginPackageProblemKind.wrongType,
      detail: metadata['type'] is String ? metadata['type'] as String : '',
    );
  }

  final name = _text(metadata['name'], 'metadata.name', min: 1, max: 80);
  final version = metadata['version'];
  if (version is! int || version < 1 || version > 2147483647) {
    throw _invalid('metadata.version');
  }
  final hosts = _hosts(metadata['hosts']);
  final author = _text(
    metadata['author'],
    'metadata.author',
    max: 80,
    optional: true,
  );
  final description = _text(
    metadata['description'],
    'metadata.description',
    max: 500,
    optional: true,
    keepNewlines: true,
  );

  final script = json['script'];
  if (script is! Map<String, dynamic>) throw _invalid('script');
  return PluginManifest(
    apiVersion: apiVersion,
    name: name,
    version: version,
    hosts: hosts,
    author: author,
    description: description,
    searchScript: _scriptRef(script['search'], 'script.search'),
    lyricsScript: _scriptRef(script['lyrics'], 'script.lyrics'),
    config: parsePluginConfig(json['config']),
  );
}

/// A string field with control characters removed and edges trimmed, then
/// length-checked. A missing optional field gives ''.
String _text(
  Object? value,
  String field, {
  int min = 0,
  required int max,
  bool optional = false,
  bool keepNewlines = false,
}) {
  if (value == null && optional) return '';
  if (value is! String) throw _invalid(field);
  final cleaned = cleanPluginText(value, keepNewlines: keepNewlines);
  final length = cleaned.runes.length;
  if (length < min || length > max) throw _invalid(field);
  return cleaned;
}

List<String> _hosts(Object? value) {
  if (value is! List || value.isEmpty || value.length > 20) {
    throw _invalid('metadata.hosts');
  }
  final hosts = <String>{};
  for (final item in value) {
    if (item is! String) throw _invalid('metadata.hosts');
    final host = item.trim().toLowerCase();
    if (lyricsHostProblem(host) != null) {
      throw PluginPackageProblem(
        PluginPackageProblemKind.badHost,
        detail: host,
      );
    }
    hosts.add(host);
  }
  return List.unmodifiable(hosts);
}

String _scriptRef(Object? value, String field) {
  if (value is! String || !_scriptName.hasMatch(value)) throw _invalid(field);
  return value;
}
