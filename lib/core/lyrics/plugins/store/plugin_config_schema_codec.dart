import 'dart:convert';

import '../package/plugin_config_parser.dart';
import '../package/plugin_manifest.dart';
import '../package/plugin_package_problem.dart';

/// Writes a config form as JSON in the shape of the manifest's `config`
/// object, so [decodePluginConfigSchema] and the manifest parser share one
/// reader. Stored in `lyrics_plugins.config_schema`.
String encodePluginConfigSchema(List<PluginConfigField> fields) =>
    jsonEncode(pluginConfigToJson(fields));

/// The manifest-shaped map of [fields].
Map<String, Object?> pluginConfigToJson(List<PluginConfigField> fields) => {
  for (final field in fields)
    field.key: {
      'title': field.title,
      'mode': field.mode.name,
      if (field.mode == PluginConfigMode.input)
        'format': (field.inputFormat ?? PluginInputFormat.text).name,
      if (field.mode == PluginConfigMode.select)
        'options': [
          for (final o in field.options) {'value': o.value, 'title': o.title},
        ],
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
  required int apiVersion,
  required String name,
  required int version,
  required List<String> hosts,
  required String author,
  required String description,
  required String searchScript,
  required String lyricsScript,
  required List<PluginConfigField> config,
}) => const JsonEncoder.withIndent('  ').convert({
  'metadata': {
    'apiVersion': apiVersion,
    'type': 'lyrics',
    'name': name,
    'version': version,
    'hosts': hosts,
    'author': author,
    'description': description,
  },
  'script': {'search': searchScript, 'lyrics': lyricsScript},
  if (config.isNotEmpty) 'config': pluginConfigToJson(config),
});
