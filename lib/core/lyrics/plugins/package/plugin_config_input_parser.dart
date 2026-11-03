import '../store/plugin_config_values.dart';
import 'plugin_config_field.dart';
import 'plugin_number_text.dart';
import 'plugin_package_problem.dart';
import 'plugin_text_clean.dart';

/// `invalidManifest` naming [field] (`config.<key>.<attr>`).
PluginPackageProblem invalidConfig(String field) => PluginPackageProblem(
  PluginPackageProblemKind.invalidManifest,
  detail: field,
);

/// Title of a field or option: 1 to 80 code points once cleaned.
String configTitle(Object? value, String field) {
  if (value is! String) throw invalidConfig(field);
  final text = cleanPluginText(value);
  if (text.isEmpty || text.runes.length > 80) throw invalidConfig(field);
  return text;
}

/// Optional help text: at most 300 characters, newlines kept.
String? configSubtitle(Object? value, String field) {
  if (value == null) return null;
  if (value is! String) throw invalidConfig(field);
  final text = cleanPluginText(value, keepNewlines: true);
  if (text.runes.length > 300) throw invalidConfig(field);
  return text.isEmpty ? null : text;
}

/// Optional placeholder: at most 200 characters; blank is none.
String? configPlaceholder(Map<String, dynamic> raw, String path) {
  final value = raw['placeholder'];
  if (value == null) return null;
  if (value is! String) throw invalidConfig('$path.placeholder');
  final text = cleanPluginText(value);
  if (text.runes.length > pluginConfigMaxPlaceholder) {
    throw invalidConfig('$path.placeholder');
  }
  return text.isEmpty ? null : text;
}

/// Optional JSON integer attribute within [min]..[max].
int? configInt(
  Map<String, dynamic> raw,
  String attr,
  String path, {
  required int min,
  required int max,
}) {
  final value = raw[attr];
  if (value == null) return null;
  if (value is! int || value < min || value > max) {
    throw invalidConfig('$path.$attr');
  }
  return value;
}

/// Optional finite JSON number attribute; an integer field takes integers
/// in the safe range only.
num? _configNumber(
  Map<String, dynamic> raw,
  String attr,
  String path, {
  required bool whole,
}) {
  final value = raw[attr];
  if (value == null) return null;
  if (value is! num || !value.isFinite) throw invalidConfig('$path.$attr');
  if (whole && (value is! int || value.abs() > pluginConfigSafeInt)) {
    throw invalidConfig('$path.$attr');
  }
  return value;
}

/// Parses an `input` field.
PluginConfigField parseInputField({
  required String key,
  required String title,
  required String? subtitle,
  required bool required,
  required Map<String, dynamic> raw,
}) {
  final path = 'config.$key';
  final format = switch (raw['format']) {
    null || 'text' => PluginInputFormat.text,
    'multiline' => PluginInputFormat.multiline,
    'number' => PluginInputFormat.number,
    'integer' => PluginInputFormat.integer,
    'secret' => PluginInputFormat.secret,
    'url' => PluginInputFormat.url,
    _ => throw invalidConfig('$path.format'),
  };
  final isText =
      format == PluginInputFormat.text || format == PluginInputFormat.multiline;
  final isNumeric =
      format == PluginInputFormat.number || format == PluginInputFormat.integer;
  final whole = format == PluginInputFormat.integer;
  final hasPlaceholder =
      format == PluginInputFormat.text ||
      format == PluginInputFormat.secret ||
      format == PluginInputFormat.url;
  final minLength = isText
      ? configInt(raw, 'minLength', path, min: 0, max: pluginConfigMaxText)
      : null;
  final maxLength = isText
      ? configInt(raw, 'maxLength', path, min: 1, max: pluginConfigMaxText)
      : null;
  if (minLength != null && maxLength != null && minLength > maxLength) {
    throw invalidConfig('$path.minLength');
  }
  final min = isNumeric ? _configNumber(raw, 'min', path, whole: whole) : null;
  final max = isNumeric ? _configNumber(raw, 'max', path, whole: whole) : null;
  if (min != null && max != null && min > max) {
    throw invalidConfig('$path.min');
  }
  final step = isNumeric
      ? _configNumber(raw, 'step', path, whole: whole)
      : null;
  if (step != null && step <= 0) throw invalidConfig('$path.step');
  final field = PluginConfigField(
    key: key,
    title: title,
    subtitle: subtitle,
    required: required,
    mode: PluginConfigMode.input,
    inputFormat: format,
    placeholder: hasPlaceholder ? configPlaceholder(raw, path) : null,
    minLength: minLength,
    maxLength: maxLength,
    rows: format == PluginInputFormat.multiline
        ? configInt(
            raw,
            'rows',
            path,
            min: pluginConfigMinRows,
            max: pluginConfigMaxRows,
          )
        : null,
    min: min,
    max: max,
    step: step,
    defaultValue: _inputDefault(raw['default'], format, '$path.default'),
  );
  if (field.defaultValue != null &&
      pluginValueProblem(field, field.defaultValue) != null) {
    throw invalidConfig('$path.default');
  }
  return field;
}

/// The typed default: a number default may be a decimal string (the form
/// the app stored before numbers were typed), kept as a number; a secret
/// has none (a string default is dropped, as older schemas stored one).
Object? _inputDefault(Object? value, PluginInputFormat format, String field) {
  if (value == null) return null;
  if (format == PluginInputFormat.secret) {
    if (value is String) return null;
    throw invalidConfig(field);
  }
  if (format == PluginInputFormat.number && value is String) {
    final parsed = parsePluginNumberText(value);
    if (parsed != null) return parsed;
  }
  final numeric =
      format == PluginInputFormat.number || format == PluginInputFormat.integer;
  if (numeric && value is! num) throw invalidConfig(field);
  return value;
}
