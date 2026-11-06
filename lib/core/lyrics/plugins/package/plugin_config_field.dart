/// How a config field is edited.
enum PluginConfigMode { input, select, toggle, list, map }

/// Entry kind of an `input` field.
enum PluginInputFormat { text, multiline, number, integer, secret, url }

/// One value or several of a `select` field.
enum PluginSelectFormat { single, multiple }

/// Item kind of a `list` field.
enum PluginListFormat { text, number, integer, url }

/// Limits shared by the manifest parser, the store and the form.
const pluginConfigMaxFields = 20;
const pluginConfigMaxItems = 50;

/// Longest text value (code points): input text, list item, map value,
/// url, secret.
const pluginConfigMaxText = 2000;
const pluginConfigMaxMapKey = 100;
const pluginConfigMaxPlaceholder = 200;
const pluginConfigMinRows = 1;
const pluginConfigMaxRows = 10;
const pluginConfigDefaultRows = 3;

/// Largest integer a script reads back exactly (a JS number).
const pluginConfigSafeInt = 9007199254740991;

/// One choice of a `select` field.
class PluginConfigOption {
  const PluginConfigOption({
    required this.value,
    required this.title,
    this.subtitle,
  });

  final String value;
  final String title;

  /// Optional second line under the title.
  final String? subtitle;
}

/// One setting a plugin asks the user for. Attributes that do not apply to
/// the field's mode and format stay null.
class PluginConfigField {
  const PluginConfigField({
    required this.key,
    required this.title,
    required this.mode,
    this.subtitle,
    this.required = false,
    this.inputFormat,
    this.selectFormat,
    this.listFormat,
    this.options = const [],
    this.custom = false,
    this.placeholder,
    this.minLength,
    this.maxLength,
    this.rows,
    this.min,
    this.max,
    this.step,
    this.minItems,
    this.maxItems,
    this.defaultValue,
  });

  /// Name the script reads with `localConfig.getItem(key)`.
  final String key;
  final String title;
  final PluginConfigMode mode;

  /// Optional help text under the title; may hold newlines.
  final String? subtitle;

  /// The run is blocked while the value is empty (a toggle ignores it).
  final bool required;

  /// Set for `input` fields only.
  final PluginInputFormat? inputFormat;

  /// Set for `select` fields only.
  final PluginSelectFormat? selectFormat;

  /// Set for `list` fields only.
  final PluginListFormat? listFormat;

  /// Set for `select` fields only.
  final List<PluginConfigOption> options;

  /// Set for a single `select` only: the user may add choices of their own,
  /// so [options] may be empty.
  final bool custom;

  final String? placeholder;
  final int? minLength;
  final int? maxLength;

  /// Visible lines of a `multiline` input.
  final int? rows;

  /// Bounds of a `number` or `integer` input.
  final num? min;
  final num? max;

  /// Arrow-key increment of a `number` or `integer` input (a hint only).
  final num? step;

  /// Item count bounds of a `list` or a `select` with `multiple`; `map`
  /// uses [maxItems] only.
  final int? minItems;
  final int? maxItems;

  /// Initial value, typed by the field: `String` (text, multiline, url,
  /// single select), `num` (number), `int` (integer), `bool` (toggle),
  /// `List<String>` (multiple select, text and url list), `List<num>` /
  /// `List<int>` (number / integer list), `Map<String, String>` (map). Null
  /// when the manifest gives none, and always for a secret.
  final Object? defaultValue;

  /// This field with [value] as its default; every other attribute stays.
  PluginConfigField withDefault(Object? value) => PluginConfigField(
    key: key,
    title: title,
    mode: mode,
    subtitle: subtitle,
    required: required,
    inputFormat: inputFormat,
    selectFormat: selectFormat,
    listFormat: listFormat,
    options: options,
    custom: custom,
    placeholder: placeholder,
    minLength: minLength,
    maxLength: maxLength,
    rows: rows,
    min: min,
    max: max,
    step: step,
    minItems: minItems,
    maxItems: maxItems,
    defaultValue: value,
  );

  /// The normalized format: `text`, `multiline`, `number`, `integer`,
  /// `secret`, `url` (input), `single`, `multiple` (select), `text`,
  /// `number`, `integer`, `url` (list); empty for toggle and map.
  String get formatName => switch (mode) {
    PluginConfigMode.input => (inputFormat ?? PluginInputFormat.text).name,
    PluginConfigMode.select => (selectFormat ?? PluginSelectFormat.single).name,
    PluginConfigMode.list => (listFormat ?? PluginListFormat.text).name,
    PluginConfigMode.toggle || PluginConfigMode.map => '',
  };
}
