import '../../core/lyrics/plugins/package/plugin_config_field.dart';
import '../../core/lyrics/plugins/store/plugin_config_values.dart';
import '../../l10n/l10n.dart';

/// A number as the user types it: no trailing `.0` on a whole value.
String pluginNumberText(num value) =>
    value is double && value.isFinite && value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

/// What to tell the user when [problem] makes a value of [field] unfit; the
/// limits come from the field.
String pluginValueProblemMessage(
  AppLocalizations l10n,
  PluginConfigField field,
  PluginValueProblem problem,
) => switch (problem) {
  PluginValueProblem.wrongType =>
    field.mode == PluginConfigMode.input &&
            field.inputFormat == PluginInputFormat.integer
        ? l10n.pluginConfigIntegerInvalid
        : field.mode == PluginConfigMode.input &&
              field.inputFormat == PluginInputFormat.number
        ? l10n.pluginConfigNumberInvalid
        : l10n.pluginConfigInvalidValue,
  PluginValueProblem.notInteger => l10n.pluginConfigIntegerInvalid,
  PluginValueProblem.tooShort => l10n.pluginConfigTooShort(
    field.minLength ?? 1,
  ),
  PluginValueProblem.tooLong => l10n.pluginConfigTooLong(
    field.maxLength ?? pluginConfigMaxText,
  ),
  PluginValueProblem.belowMin =>
    field.min == null
        ? l10n.pluginConfigInvalidValue
        : l10n.pluginConfigBelowMin(pluginNumberText(field.min!)),
  PluginValueProblem.aboveMax =>
    field.max == null
        ? l10n.pluginConfigInvalidValue
        : l10n.pluginConfigAboveMax(pluginNumberText(field.max!)),
  PluginValueProblem.tooFewItems => l10n.pluginConfigTooFewItems(
    field.minItems ?? 1,
  ),
  PluginValueProblem.tooManyItems => l10n.pluginConfigTooManyItems(
    field.maxItems ?? pluginConfigMaxItems,
  ),
  PluginValueProblem.badUrl => l10n.pluginConfigUrlInvalid,
  PluginValueProblem.badItem => l10n.pluginConfigItemInvalid,
  PluginValueProblem.badKey => l10n.pluginConfigKeyInvalid,
  PluginValueProblem.notOption => l10n.pluginConfigInvalidValue,
};
