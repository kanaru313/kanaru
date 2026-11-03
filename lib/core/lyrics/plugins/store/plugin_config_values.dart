import '../package/plugin_config_field.dart';
import 'plugin_config_value_rules.dart';

/// How [LyricsPluginConfigStore.setValue] ended.
enum PluginConfigWrite {
  written,

  /// No live plugin, or the form has no such key.
  unknownKey,

  /// The value does not fit the field (wrong type, not an option, not a
  /// number).
  invalidValue,

  /// The non-secret values would pass the size cap.
  tooLarge,

  /// The secret store refused the write (locked, absent).
  secretStoreFailed,
}

/// Why a value does not fit its field.
enum PluginValueProblem {
  wrongType,
  tooShort,
  tooLong,
  belowMin,
  aboveMax,
  notInteger,
  notOption,
  tooFewItems,
  tooManyItems,
  badUrl,
  badItem,
  badKey,

  /// Two map rows share a key. A stored map cannot hold this; the editor
  /// reports it for rows it has not saved.
  duplicateKey,
}

/// Whether [value] is a legal value of [field] (emptiness is not checked:
/// `required` is the caller's concern).
bool pluginValueFits(PluginConfigField field, Object? value) =>
    pluginValueProblem(field, value) == null;

/// The first rule [value] breaks for [field], or null when it fits. Lists
/// and maps may be JSON-decoded (`List<dynamic>`, `Map<String, dynamic>`).
PluginValueProblem? pluginValueProblem(PluginConfigField field, Object? value) {
  switch (field.mode) {
    case PluginConfigMode.toggle:
      return value is bool ? null : PluginValueProblem.wrongType;
    case PluginConfigMode.select:
      return field.selectFormat == PluginSelectFormat.multiple
          ? _multiple(field, value)
          : _single(field, value);
    case PluginConfigMode.input:
      return _input(field, value);
    case PluginConfigMode.list:
      return _list(field, value);
    case PluginConfigMode.map:
      return _map(field, value);
  }
}

PluginValueProblem? _single(PluginConfigField field, Object? value) {
  if (value is! String) return PluginValueProblem.wrongType;
  return field.options.any((o) => o.value == value)
      ? null
      : PluginValueProblem.notOption;
}

PluginValueProblem? _multiple(PluginConfigField field, Object? value) {
  if (value is! List) return PluginValueProblem.wrongType;
  final seen = <Object?>{};
  for (final item in value) {
    if (item is! String) return PluginValueProblem.badItem;
    if (!field.options.any((o) => o.value == item)) {
      return PluginValueProblem.notOption;
    }
    if (!seen.add(item)) return PluginValueProblem.badItem;
  }
  return _count(field, value.length, field.options.length);
}

PluginValueProblem? _count(PluginConfigField field, int count, int cap) {
  if (count < (field.minItems ?? 0)) return PluginValueProblem.tooFewItems;
  final max = field.maxItems ?? cap;
  if (count > (max < cap ? max : cap)) return PluginValueProblem.tooManyItems;
  return null;
}

PluginValueProblem? _input(PluginConfigField field, Object? value) {
  final format = field.inputFormat ?? PluginInputFormat.text;
  switch (format) {
    case PluginInputFormat.number:
    case PluginInputFormat.integer:
      final number = _numberOf(value, format == PluginInputFormat.integer);
      if (number == null) {
        return value is num && format == PluginInputFormat.integer
            ? PluginValueProblem.notInteger
            : PluginValueProblem.wrongType;
      }
      if (number is int && number.abs() > pluginConfigSafeInt) {
        return number < 0
            ? PluginValueProblem.belowMin
            : PluginValueProblem.aboveMax;
      }
      return _range(field, number);
    case PluginInputFormat.secret:
      if (value is! String) return PluginValueProblem.wrongType;
      return value.runes.length > pluginConfigMaxText
          ? PluginValueProblem.tooLong
          : null;
    case PluginInputFormat.url:
      if (value is! String) return PluginValueProblem.wrongType;
      return pluginUrlProblem(value);
    case PluginInputFormat.text:
    case PluginInputFormat.multiline:
      if (value is! String) return PluginValueProblem.wrongType;
      final length = value.runes.length;
      if (length < (field.minLength ?? 0)) return PluginValueProblem.tooShort;
      if (length > (field.maxLength ?? pluginConfigMaxText)) {
        return PluginValueProblem.tooLong;
      }
      return null;
  }
}

/// [value] as a finite number (an integer in the safe range when
/// [whole]), or null. A string is never read as a number.
num? _numberOf(Object? value, bool whole) {
  if (value is! num || !value.isFinite) return null;
  if (whole && value is! int) return null;
  return value;
}

PluginValueProblem? _range(PluginConfigField field, num number) {
  final min = field.min;
  final max = field.max;
  if (min != null && number < min) return PluginValueProblem.belowMin;
  if (max != null && number > max) return PluginValueProblem.aboveMax;
  return null;
}

PluginValueProblem? _list(PluginConfigField field, Object? value) {
  if (value is! List) return PluginValueProblem.wrongType;
  final problem = _count(field, value.length, pluginConfigMaxItems);
  if (problem != null) return problem;
  final format = field.listFormat ?? PluginListFormat.text;
  for (final item in value) {
    final ok = switch (format) {
      PluginListFormat.text =>
        item is String &&
            item.trim().isNotEmpty &&
            item.runes.length <= pluginConfigMaxText,
      PluginListFormat.url => item is String && pluginUrlProblem(item) == null,
      PluginListFormat.number => _numberOf(item, false) != null && item is num,
      PluginListFormat.integer =>
        item is int && item.abs() <= pluginConfigSafeInt,
    };
    if (!ok) return PluginValueProblem.badItem;
  }
  return null;
}

PluginValueProblem? _map(PluginConfigField field, Object? value) {
  if (value is! Map) return PluginValueProblem.wrongType;
  final max = field.maxItems ?? pluginConfigMaxItems;
  if (value.length >
      (max < pluginConfigMaxItems ? max : pluginConfigMaxItems)) {
    return PluginValueProblem.tooManyItems;
  }
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String || !pluginMapKeyIsValid(key)) {
      return PluginValueProblem.badKey;
    }
    final item = entry.value;
    if (item is! String || item.runes.length > pluginConfigMaxText) {
      return PluginValueProblem.badItem;
    }
  }
  return null;
}
