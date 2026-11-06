import 'dart:convert';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../../../database/lyrics_plugin_spec.dart';
import '../../online/lyrics_provider_registry.dart';
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
    'ai-translate' => PluginKind.aiTranslate,
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

  final languages = parsePluginLanguages(metadata['languages']);

  final script = json['script'];
  if (script is! Map<String, dynamic>) throw _invalid('script');
  PluginTranslateSpec? translate;
  if (kind.isTranslation) {
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
  final config = parsePluginConfig(json['config']);
  _checkCustomFields(kind, config);
  if (kind == PluginKind.aiTranslate) _requireTuneFields(config);
  final isLyrics = kind == PluginKind.lyrics;
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
    searchScript: isLyrics
        ? _scriptRef(script['search'], 'script.search')
        : null,
    lyricsScript: isLyrics
        ? _scriptRef(script['lyrics'], 'script.lyrics')
        : null,
    translateScript: kind.isTranslation
        ? _scriptRef(script['translate'], 'script.translate')
        : null,
    config: config,
  );
}

/// `custom` is for the `model` select of an `ai-translate` plugin only.
void _checkCustomFields(PluginKind kind, List<PluginConfigField> config) {
  for (final field in config) {
    if (field.custom &&
        !(kind == PluginKind.aiTranslate && field.key == 'model')) {
      throw _invalid('config.${field.key}.custom');
    }
  }
}

/// The fields an `ai-translate` plugin must declare: `model` and `style`
/// (single selects) and `customInstruction` (a plain text input). A custom
/// `model` must be required, so an empty list reads as needing setup.
void _requireTuneFields(List<PluginConfigField> config) {
  PluginConfigField? find(String key) {
    for (final field in config) {
      if (field.key == key) return field;
    }
    return null;
  }

  for (final key in const ['model', 'style']) {
    final field = find(key);
    if (field == null ||
        field.mode != PluginConfigMode.select ||
        field.formatName != PluginSelectFormat.single.name ||
        (field.options.isEmpty && !field.custom)) {
      throw _invalid('config.$key');
    }
  }
  if (find('model')!.custom && !find('model')!.required) {
    throw _invalid('config.model.required');
  }
  final instruction = find('customInstruction');
  if (instruction == null ||
      instruction.mode != PluginConfigMode.input ||
      instruction.formatName != PluginInputFormat.text.name) {
    throw _invalid('config.customInstruction');
  }
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
