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
/// mode and format, and the value still fits. [stored] is all the stored
/// values: the choices a user added to a `custom` select (`model.custom`) are
/// kept while the new form's field is still `custom` and dropped otherwise,
/// and a selected choice of the user's only fits while they are kept.
bool keepsStoredValue(
  List<PluginConfigField> before,
  List<PluginConfigField> after,
  String key,
  Object? value, [
  Map<String, Object?> stored = const {},
]) {
  final owner = after
      .where((f) => pluginCustomChoicesKey(f.key) == key)
      .firstOrNull;
  if (owner != null) return owner.custom && !isSecretField(owner);
  var field = after.where((f) => f.key == key).firstOrNull;
  if (field == null || isSecretField(field)) return false;
  field = pluginEffectiveField(field, stored);
  final old = before.where((f) => f.key == key).firstOrNull;
  if (old != null &&
      (old.mode != field.mode || old.formatName != field.formatName)) {
    return false;
  }
  return pluginValueFits(field, value);
}
