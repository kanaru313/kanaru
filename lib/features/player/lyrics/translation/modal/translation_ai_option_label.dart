import '../../../../../core/lyrics/plugins/package/plugin_manifest.dart';
import '../../../../../core/lyrics/plugins/store/plugin_config_values.dart';
import '../../../../../l10n/l10n.dart';

/// How a model or style is shown: the title of the option the run uses now
/// (from the effective [field], so a model the user added counts), the saved
/// raw value with "no longer supported" when the plugin dropped it, or "not
/// chosen" when nothing is saved and there is no default.
({String title, String? subtitle, bool chosen}) aiOptionLabel(
  AppLocalizations l10n,
  PluginConfigField field,
  Map<String, Object?> stored,
) {
  final effective = pluginEffectiveValue(field, stored);
  if (effective is String) {
    for (final option in field.options) {
      if (option.value == effective) {
        return (title: option.title, subtitle: option.subtitle, chosen: true);
      }
    }
  }
  final raw = stored[field.key];
  if (raw is String && raw.isNotEmpty) {
    return (
      title: l10n.translationAiOptionGone(raw),
      subtitle: null,
      chosen: false,
    );
  }
  return (title: l10n.translationAiNotChosen, subtitle: null, chosen: false);
}
