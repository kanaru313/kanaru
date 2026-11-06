import 'plugin_config_collection_parser.dart';
import 'plugin_config_field.dart';
import 'plugin_config_input_parser.dart';

final _configKey = RegExp(r'^[A-Za-z0-9_]{1,40}$');

/// Parses the optional `config` object (at most 20 fields, kept in manifest
/// order). Throws `invalidManifest` naming `config.<key>.<attr>`. Attributes
/// that do not apply to a field's mode and format are ignored, except
/// `custom`, which any field but a `select` refuses.
List<PluginConfigField> parsePluginConfig(Object? value) {
  if (value == null) return const [];
  if (value is! Map<String, dynamic> || value.length > pluginConfigMaxFields) {
    throw invalidConfig('config');
  }
  return List.unmodifiable([
    for (final entry in value.entries) _field(entry.key, entry.value),
  ]);
}

PluginConfigField _field(String key, Object? raw) {
  final path = 'config.$key';
  if (!_configKey.hasMatch(key)) throw invalidConfig(path);
  if (raw is! Map<String, dynamic>) throw invalidConfig(path);
  if (raw['custom'] != null && raw['mode'] != 'select') {
    throw invalidConfig('$path.custom');
  }
  final title = configTitle(raw['title'], '$path.title');
  final subtitle = configSubtitle(raw['subtitle'], '$path.subtitle');
  final required = switch (raw['required']) {
    null => false,
    final bool flag => flag,
    _ => throw invalidConfig('$path.required'),
  };
  switch (raw['mode']) {
    case 'input':
      return parseInputField(
        key: key,
        title: title,
        subtitle: subtitle,
        required: required,
        raw: raw,
      );
    case 'select':
      return parseSelectField(
        key: key,
        title: title,
        subtitle: subtitle,
        required: required,
        raw: raw,
      );
    case 'list':
      return parseListField(
        key: key,
        title: title,
        subtitle: subtitle,
        required: required,
        raw: raw,
      );
    case 'map':
      return parseMapField(
        key: key,
        title: title,
        subtitle: subtitle,
        required: required,
        raw: raw,
      );
    case 'toggle':
      if (raw['format'] != null) throw invalidConfig('$path.format');
      final fallback = raw['default'];
      if (fallback != null && fallback is! bool) {
        throw invalidConfig('$path.default');
      }
      return PluginConfigField(
        key: key,
        title: title,
        subtitle: subtitle,
        required: required,
        mode: PluginConfigMode.toggle,
        defaultValue: fallback,
      );
    default:
      throw invalidConfig('$path.mode');
  }
}
