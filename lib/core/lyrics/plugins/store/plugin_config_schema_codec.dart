import 'dart:convert';

import '../../../database/lyrics_plugin_spec.dart';
import '../package/plugin_config_parser.dart';
import '../package/plugin_manifest.dart';
import '../package/plugin_package_problem.dart';
import '../package/plugin_translate_spec.dart';

/// Writes a config form as JSON in the shape of the manifest's `config`
/// object, so [decodePluginConfigSchema] and the manifest parser share one
/// reader. Stored in `lyrics_plugins.config_schema`.
String encodePluginConfigSchema(List<PluginConfigField> fields) =>
    jsonEncode(pluginConfigToJson(fields));

/// The manifest-shaped map of [fields]. An attribute is written only when
/// set, so the text parses back to equal fields.
Map<String, Object?> pluginConfigToJson(List<PluginConfigField> fields) => {
  for (final field in fields)
    field.key: {
      'title': field.title,
      'mode': field.mode.name,
      if (field.subtitle != null) 'subtitle': field.subtitle,
      if (field.required) 'required': true,
      if (field.formatName.isNotEmpty) 'format': field.formatName,
      if (field.mode == PluginConfigMode.select)
        'options': [
          for (final o in field.options)
            {
              'value': o.value,
              'title': o.title,
              if (o.subtitle != null) 'subtitle': o.subtitle,
            },
        ],
      if (field.placeholder != null) 'placeholder': field.placeholder,
      if (field.minLength != null) 'minLength': field.minLength,
      if (field.maxLength != null) 'maxLength': field.maxLength,
      if (field.rows != null) 'rows': field.rows,
      if (field.min != null) 'min': field.min,
      if (field.max != null) 'max': field.max,
      if (field.step != null) 'step': field.step,
      if (field.minItems != null) 'minItems': field.minItems,
      if (field.maxItems != null) 'maxItems': field.maxItems,
      if (field.defaultValue != null) 'default': field.defaultValue,
    },
};

/// Reads a stored config form. Text this layer did not write (a newer build)
/// gives an empty form rather than an error.
List<PluginConfigField> decodePluginConfigSchema(String json) {
  try {
    return parsePluginConfig(jsonDecode(json));
  } on PluginPackageProblem {
    return const [];
  } on FormatException {
    return const [];
  }
}

/// Whether [field] holds a secret (kept in the secret store, never in the
/// database).
bool isSecretField(PluginConfigField field) =>
    field.mode == PluginConfigMode.input &&
    field.inputFormat == PluginInputFormat.secret;

/// The `plugin.json` text of a package written to disk.
String pluginManifestJson({
  required PluginKind kind,
  required int apiVersion,
  required String name,
  required int version,
  required List<String> hosts,
  required String author,
  required String description,
  List<String> languages = const [],
  String? searchScript,
  String? lyricsScript,
  String? translateScript,
  PluginTranslateSpec? translate,
  required List<PluginConfigField> config,
}) => const JsonEncoder.withIndent('  ').convert({
  'metadata': {
    'apiVersion': apiVersion,
    'type': kind.value,
    'name': name,
    'version': version,
    'hosts': hosts,
    'author': author,
    'description': description,
    if (languages.isNotEmpty) 'languages': languages,
  },
  'script': {
    'search': ?searchScript,
    'lyrics': ?lyricsScript,
    'translate': ?translateScript,
  },
  if (translate != null) 'translate': translate.toJson(),
  if (config.isNotEmpty) 'config': pluginConfigToJson(config),
});
