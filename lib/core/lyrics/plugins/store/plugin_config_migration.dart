import '../package/plugin_config_field.dart';
import 'plugin_config_schema_codec.dart';
import 'plugin_config_values.dart';

/// Whether a stored value of [old] may move to the keyring as the value of
/// [now]: only a plain text input that became a secret. Any other kind of
/// value (a choice, a url, a number) is not a credential the user typed.
bool movesIntoSecret(PluginConfigField old, PluginConfigField now) =>
    !isSecretField(old) &&
    isSecretField(now) &&
    old.mode == PluginConfigMode.input &&
    (old.inputFormat ?? PluginInputFormat.text) == PluginInputFormat.text;

/// Whether the stored [value] of [key] is kept when the form goes from
/// [before] to [after]: its field still exists as a non-secret one, kept its
/// mode and format, and the value still fits.
bool keepsStoredValue(
  List<PluginConfigField> before,
  List<PluginConfigField> after,
  String key,
  Object? value,
) {
  final field = after.where((f) => f.key == key).firstOrNull;
  if (field == null || isSecretField(field)) return false;
  final old = before.where((f) => f.key == key).firstOrNull;
  if (old != null &&
      (old.mode != field.mode || old.formatName != field.formatName)) {
    return false;
  }
  return pluginValueFits(field, value);
}
