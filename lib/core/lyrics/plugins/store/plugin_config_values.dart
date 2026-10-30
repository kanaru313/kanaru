import '../package/plugin_manifest.dart';

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

final _decimal = RegExp(r'^-?\d+(\.\d+)?([eE][+-]?\d+)?$');

/// Whether [value] is a legal value of [field].
bool pluginValueFits(PluginConfigField field, Object? value) {
  switch (field.mode) {
    case PluginConfigMode.toggle:
      return value is bool;
    case PluginConfigMode.select:
      return value is String && field.options.any((o) => o.value == value);
    case PluginConfigMode.input:
      if (value is! String) return false;
      return field.inputFormat != PluginInputFormat.number ||
          _decimal.hasMatch(value);
  }
}
