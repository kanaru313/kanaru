import 'dart:convert';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../../../database/lyrics_plugin_spec.dart';
import '../../online/plugin_host_patterns.dart';
import 'plugin_config_parser.dart';
import 'plugin_languages.dart';
import 'plugin_manifest.dart';
import 'plugin_package_problem.dart';
import 'plugin_text_clean.dart';
import 'plugin_translate_spec.dart';

final _log = Logger('plugin_package');

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
  final kind = switch (metadata['type']) {
    'lyrics' => PluginKind.lyrics,
    'translate' => PluginKind.translate,
    'source' => PluginKind.source,
    _ => null,
  };
  if (kind == null) {
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
  final hosts = _hosts(
    metadata['hosts'],
    wildcardsAllowed: kind == PluginKind.source,
  );
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

  final languages = parsePluginLanguages(metadata['languages']);

  final script = json['script'];
  if (script is! Map<String, dynamic>) throw _invalid('script');
  PluginTranslateSpec? translate;
  if (kind == PluginKind.translate) {
    try {
      final parsed = parsePluginTranslateSpec(json['translate']);
      translate = parsed.spec;
      if (parsed.droppedLanguages > 0) {
        _log.info(
          'translate plugin lists ${parsed.droppedLanguages} unsupported '
          'or repeated language codes; they are ignored',
        );
      }
    } on PluginTranslateSpecError catch (error) {
      throw _invalid(error.field);
    }
  }
  final isLyrics = kind == PluginKind.lyrics;
  final isSource = kind == PluginKind.source;
  return PluginManifest(
    kind: kind,
    translate: translate,
    apiVersion: apiVersion,
    name: name,
    version: version,
    hosts: hosts,
    author: author,
    description: description,
    languages: languages,
    searchScript: isLyrics || isSource
        ? _scriptRef(script['search'], 'script.search')
        : null,
    lyricsScript: isLyrics
        ? _scriptRef(script['lyrics'], 'script.lyrics')
        : null,
    translateScript: kind == PluginKind.translate
        ? _scriptRef(script['translate'], 'script.translate')
        : null,
    streamScript: isSource
        ? _scriptRef(script['stream'], 'script.stream')
        : null,
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

List<String> _hosts(Object? value, {required bool wildcardsAllowed}) {
  if (value is! List || value.isEmpty || value.length > 20) {
    throw _invalid('metadata.hosts');
  }
  final hosts = <String>{};
  for (final item in value) {
    if (item is! String) throw _invalid('metadata.hosts');
    hosts.add(item.trim().toLowerCase());
  }
  final problem = pluginHostListProblem(
    hosts.toList(),
    wildcardsAllowed: wildcardsAllowed,
  );
  if (problem != null) {
    throw PluginPackageProblem(
      PluginPackageProblemKind.badHost,
      detail: problem.entry,
    );
  }
  return List.unmodifiable(hosts);
}

String _scriptRef(Object? value, String field) {
  if (value is! String || !_scriptName.hasMatch(value)) throw _invalid(field);
  return value;
}
