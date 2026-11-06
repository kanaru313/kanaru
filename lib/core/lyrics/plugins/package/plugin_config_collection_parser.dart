import '../store/plugin_config_values.dart';
import 'plugin_config_field.dart';
import 'plugin_config_input_parser.dart';

/// Parses a `select` field.
PluginConfigField parseSelectField({
  required String key,
  required String title,
  required String? subtitle,
  required bool required,
  required Map<String, dynamic> raw,
}) {
  final path = 'config.$key';
  final format = switch (raw['format']) {
    null || 'single' => PluginSelectFormat.single,
    'multiple' => PluginSelectFormat.multiple,
    _ => throw invalidConfig('$path.format'),
  };
  final custom = switch (raw['custom']) {
    null => false,
    final bool flag => flag,
    _ => throw invalidConfig('$path.custom'),
  };
  // The user adds the choices of a custom select, so the plugin may list none.
  if (custom && format == PluginSelectFormat.multiple) {
    throw invalidConfig('$path.custom');
  }
  final options = _options(raw['options'], '$path.options', allowEmpty: custom);
  final multiple = format == PluginSelectFormat.multiple;
  final (minItems, maxItems) = multiple
      ? _itemBounds(raw, path, options.length)
      : (null, null);
  return _checked(
    PluginConfigField(
      key: key,
      title: title,
      subtitle: subtitle,
      required: required,
      mode: PluginConfigMode.select,
      selectFormat: format,
      options: options,
      custom: custom,
      minItems: minItems,
      maxItems: maxItems,
      defaultValue: raw['default'],
    ),
    path,
  );
}

/// Parses a `list` field.
PluginConfigField parseListField({
  required String key,
  required String title,
  required String? subtitle,
  required bool required,
  required Map<String, dynamic> raw,
}) {
  final path = 'config.$key';
  final format = switch (raw['format']) {
    null || 'text' => PluginListFormat.text,
    'number' => PluginListFormat.number,
    'integer' => PluginListFormat.integer,
    'url' => PluginListFormat.url,
    _ => throw invalidConfig('$path.format'),
  };
  final (minItems, maxItems) = _itemBounds(raw, path, pluginConfigMaxItems);
  return _checked(
    PluginConfigField(
      key: key,
      title: title,
      subtitle: subtitle,
      required: required,
      mode: PluginConfigMode.list,
      listFormat: format,
      placeholder: configPlaceholder(raw, path),
      minItems: minItems,
      maxItems: maxItems,
      defaultValue: raw['default'],
    ),
    path,
  );
}

/// Parses a `map` field (text keys and text values).
PluginConfigField parseMapField({
  required String key,
  required String title,
  required String? subtitle,
  required bool required,
  required Map<String, dynamic> raw,
}) {
  final path = 'config.$key';
  if (raw['format'] != null && raw['format'] != 'text') {
    throw invalidConfig('$path.format');
  }
  return _checked(
    PluginConfigField(
      key: key,
      title: title,
      subtitle: subtitle,
      required: required,
      mode: PluginConfigMode.map,
      maxItems: configInt(
        raw,
        'maxItems',
        path,
        min: 1,
        max: pluginConfigMaxItems,
      ),
      defaultValue: raw['default'],
    ),
    path,
  );
}

(int?, int?) _itemBounds(Map<String, dynamic> raw, String path, int cap) {
  final min = configInt(raw, 'minItems', path, min: 0, max: cap);
  final max = configInt(raw, 'maxItems', path, min: 1, max: cap);
  if (min != null && max != null && min > max) {
    throw invalidConfig('$path.minItems');
  }
  return (min, max);
}

/// [field] with its default checked and given its typed form.
PluginConfigField _checked(PluginConfigField field, String path) {
  final value = field.defaultValue;
  if (value == null) return field;
  if (pluginValueProblem(field, value) != null) {
    throw invalidConfig('$path.default');
  }
  final typed = switch (field.mode) {
    PluginConfigMode.map => Map<String, String>.unmodifiable(
      Map<String, String>.from(value as Map),
    ),
    PluginConfigMode.list when field.listFormat == PluginListFormat.number =>
      List<num>.unmodifiable(List<num>.from(value as List)),
    PluginConfigMode.list when field.listFormat == PluginListFormat.integer =>
      List<int>.unmodifiable(List<int>.from(value as List)),
    _ when value is List => List<String>.unmodifiable(List<String>.from(value)),
    _ => value,
  };
  return field.withDefault(typed);
}

List<PluginConfigOption> _options(
  Object? value,
  String field, {
  bool allowEmpty = false,
}) {
  // A custom select may leave `options` out too.
  if (allowEmpty && value == null) return const [];
  if (value is! List ||
      (value.isEmpty && !allowEmpty) ||
      value.length > pluginConfigMaxItems) {
    throw invalidConfig(field);
  }
  final options = <PluginConfigOption>[];
  final seen = <String>{};
  for (final item in value) {
    if (item is! Map<String, dynamic>) throw invalidConfig(field);
    final optionValue = item['value'];
    if (optionValue is! String ||
        optionValue.isEmpty ||
        optionValue.runes.length > 200 ||
        !seen.add(optionValue)) {
      throw invalidConfig(field);
    }
    options.add(
      PluginConfigOption(
        value: optionValue,
        title: configTitle(item['title'], field),
        subtitle: configSubtitle(item['subtitle'], field),
      ),
    );
  }
  return List.unmodifiable(options);
}
