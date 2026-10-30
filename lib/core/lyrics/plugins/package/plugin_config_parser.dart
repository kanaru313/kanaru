import 'plugin_manifest.dart';
import 'plugin_package_problem.dart';
import 'plugin_text_clean.dart';

// Plain decimal text: no NaN, Infinity, hex or surrounding spaces.
final _decimal = RegExp(r'^-?\d+(\.\d+)?([eE][+-]?\d+)?$');
final _configKey = RegExp(r'^[A-Za-z0-9_]{1,40}$');

PluginPackageProblem _invalid(String field) => PluginPackageProblem(
  PluginPackageProblemKind.invalidManifest,
  detail: field,
);

/// Parses the optional `config` object (at most 20 fields, kept in manifest
/// order). Throws `invalidManifest` naming `config.<key>.<attr>`.
List<PluginConfigField> parsePluginConfig(Object? value) {
  if (value == null) return const [];
  if (value is! Map<String, dynamic> || value.length > 20) {
    throw _invalid('config');
  }
  return List.unmodifiable([
    for (final entry in value.entries) _field(entry.key, entry.value),
  ]);
}

PluginConfigField _field(String key, Object? raw) {
  final path = 'config.$key';
  if (!_configKey.hasMatch(key)) throw _invalid(path);
  if (raw is! Map<String, dynamic>) throw _invalid(path);
  final title = _title(raw['title'], '$path.title');
  final fallback = raw['default'];
  switch (raw['mode']) {
    case 'input':
      final format = switch (raw['format']) {
        null || 'text' => PluginInputFormat.text,
        'number' => PluginInputFormat.number,
        'secret' => PluginInputFormat.secret,
        _ => throw _invalid('$path.format'),
      };
      return PluginConfigField(
        key: key,
        title: title,
        mode: PluginConfigMode.input,
        inputFormat: format,
        defaultValue: _inputDefault(fallback, format, '$path.default'),
      );
    case 'select':
      if (raw['format'] != null && raw['format'] != 'single') {
        throw _invalid('$path.format');
      }
      final options = _options(raw['options'], '$path.options');
      if (fallback != null &&
          (fallback is! String || !options.any((o) => o.value == fallback))) {
        throw _invalid('$path.default');
      }
      return PluginConfigField(
        key: key,
        title: title,
        mode: PluginConfigMode.select,
        options: options,
        defaultValue: fallback,
      );
    case 'toggle':
      if (raw['format'] != null) throw _invalid('$path.format');
      if (fallback != null && fallback is! bool) {
        throw _invalid('$path.default');
      }
      return PluginConfigField(
        key: key,
        title: title,
        mode: PluginConfigMode.toggle,
        defaultValue: fallback,
      );
    default:
      throw _invalid('$path.mode');
  }
}

String _title(Object? value, String field) {
  if (value is! String) throw _invalid(field);
  final text = cleanPluginText(value);
  if (text.isEmpty || text.runes.length > 80) throw _invalid(field);
  return text;
}

/// A text default is a string; a number default may also be a JSON number,
/// kept as text because config values reach scripts as strings.
String? _inputDefault(Object? value, PluginInputFormat format, String field) {
  if (value == null) return null;
  if (format == PluginInputFormat.number) {
    if (value is num && value.isFinite) return '$value';
    if (value is String && _decimal.hasMatch(value)) {
      final parsed = num.tryParse(value);
      if (parsed != null && parsed.isFinite) return value;
    }
    throw _invalid(field);
  }
  if (value is String) return value;
  throw _invalid(field);
}

List<PluginConfigOption> _options(Object? value, String field) {
  if (value is! List || value.isEmpty || value.length > 50) {
    throw _invalid(field);
  }
  final options = <PluginConfigOption>[];
  final seen = <String>{};
  for (final item in value) {
    if (item is! Map<String, dynamic>) throw _invalid(field);
    final optionValue = item['value'];
    if (optionValue is! String ||
        optionValue.isEmpty ||
        optionValue.runes.length > 200 ||
        !seen.add(optionValue)) {
      throw _invalid(field);
    }
    options.add(
      PluginConfigOption(
        value: optionValue,
        title: _title(item['title'], field),
      ),
    );
  }
  return List.unmodifiable(options);
}
