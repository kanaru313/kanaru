import 'dart:convert';

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

/// The key under which the user's own choices of a `custom` select are kept
/// among the stored values (`model.custom`). It holds a list of
/// `{value, subtitle?}` and never reaches a script.
String pluginCustomChoicesKey(String fieldKey) => '$fieldKey.custom';

/// [field] as it is for the user: a `custom` single select gains the choices
/// the user added (stored under [pluginCustomChoicesKey]) after the plugin's
/// own options. Any other field is returned as is. Entries that are not a
/// well-formed `{value: String}`, repeat an option, or pass the item cap are
/// ignored.
PluginConfigField pluginEffectiveField(
  PluginConfigField field,
  Map<String, Object?> stored,
) {
  final raw = stored[pluginCustomChoicesKey(field.key)];
  if (!field.custom || raw is! List) return field;
  final options = [...field.options];
  final seen = {for (final o in options) o.value};
  for (final item in raw) {
    if (options.length >= pluginConfigMaxItems) break;
    if (item is! Map) continue;
    final value = item['value'];
    final subtitle = item['subtitle'];
    if (value is! String || value.isEmpty || !seen.add(value)) continue;
    options.add(
      PluginConfigOption(
        value: value,
        title: value,
        subtitle: subtitle is String && subtitle.isNotEmpty ? subtitle : null,
        custom: true,
      ),
    );
  }
  return field.withOptions(options);
}

/// What a run reads for a non-secret [field]: the stored value, else the
/// default, and null when that does not fit the field (it never falls back to
/// the default then). The same rule as `configForRun`, so a comparison with
/// what a run used does not see a difference that is not one. [field] should
/// come from [pluginEffectiveField] for a select.
Object? pluginEffectiveValue(
  PluginConfigField field,
  Map<String, Object?> stored,
) {
  final value = stored[field.key] ?? field.defaultValue;
  return value != null && pluginValueFits(field, value) ? value : null;
}

/// Longest instruction a script is given (code points): the shared text and
/// the song's note, each held to [pluginConfigMaxText] when stored, and one
/// separator. A field's own `required` / `maxLength` apply to the stored
/// shared value only; the joined text is passed unchecked, only held to this
/// bound so a damaged stored value cannot grow a request without limit.
const aiInstructionMaxRunes = 2 * pluginConfigMaxText + 1;

/// The instruction a script receives: the shared text, then the song's note,
/// on separate lines, either left out when empty, held to
/// [aiInstructionMaxRunes].
String combinedInstruction(String shared, String? song) {
  final text = [shared, song ?? ''].where((s) => s.isNotEmpty).join('\n');
  final runes = text.runes;
  return runes.length <= aiInstructionMaxRunes
      ? text
      : String.fromCharCodes(runes.take(aiInstructionMaxRunes));
}

/// The key of the standard model select of an `ai-translate` plugin, the one
/// field that may be `custom`.
const pluginModelKey = 'model';

/// Longest name of a model the user adds, and its note (code points).
const pluginCustomChoiceMaxValue = 200;
const pluginCustomChoiceMaxSubtitle = 300;

/// The values stored as JSON text, decoded. Unreadable text, or text that is
/// not an object, counts as no values.
Map<String, Object?> decodeStoredPluginConfig(String text) {
  try {
    final value = jsonDecode(text);
    if (value is Map<String, dynamic>) return {...value};
  } on FormatException {
    // Unreadable text counts as no values.
  }
  return {};
}
