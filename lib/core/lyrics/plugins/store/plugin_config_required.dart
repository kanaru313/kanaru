import '../../../plugin_runtime/plugin_runtime.dart';
import '../package/plugin_config_field.dart';

/// The required fields of [schema] that have no usable value in [config]
/// (what a run would read). Empty means the plugin may run.
///
/// A value is missing when it is absent, an empty string, or an empty list
/// or map (a secret of only spaces too). A toggle is never missing (off is
/// an answer). A default counts as a value: [config] already holds it, and a
/// secret has no default.
List<PluginConfigField> missingRequiredConfig(
  List<PluginConfigField> schema,
  PluginConfigMap config,
) => [
  for (final field in schema)
    if (field.required &&
        field.mode != PluginConfigMode.toggle &&
        _isEmpty(config[field.key], trim: _isSecret(field)))
      field,
];

bool _isSecret(PluginConfigField field) =>
    field.mode == PluginConfigMode.input &&
    field.inputFormat == PluginInputFormat.secret;

// A secret of spaces is never a credential; other text is taken literally.
bool _isEmpty(Object? value, {required bool trim}) => switch (value) {
  null => true,
  String s => (trim ? s.trim() : s).isEmpty,
  List l => l.isEmpty,
  Map m => m.isEmpty,
  _ => false,
};
