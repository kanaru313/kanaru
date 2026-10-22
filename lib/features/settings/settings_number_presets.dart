import '../../l10n/l10n.dart';
import 'setting_choice.dart';

/// Values the numeric options offer in their dropdowns; 0 means off.
const minFileSizePresetsKb = [0, 100, 500, 1024, 2048, 5120];
const minDurationPresetsSeconds = [0, 10, 30, 60, 120];
const crossfadePresetsSeconds = [0, 2, 4, 6, 8, 10, 12];
const fadePresetsMs = [0, 100, 200, 300, 500, 1000];
const listenMinutesPresets = [1, 2, 3, 4, 5, 6, 8, 10];
const listenPercentPresets = [10, 25, 50, 75, 100];
const fontScalePresets = [0.8, 0.9, 1.0, 1.1, 1.25, 1.5];

/// The dropdown entries for [presets], with [current] added in its place
/// when it is not one of them (a value typed into `settings.json`), so the
/// control always shows what is stored.
List<SettingOption<T>> presetOptions<T extends num>(
  List<T> presets,
  T current,
  String Function(T value) label,
) {
  final values = presets.contains(current)
      ? presets
      : ([...presets, current]..sort());
  return [for (final v in values) SettingOption(value: v, label: label(v))];
}

/// 0 reads "Off"; sizes from 1 MB up read in MB.
String formatFileSizeKb(AppLocalizations l10n, int kb) {
  if (kb == 0) return l10n.settingsOff;
  return kb < 1024 ? l10n.settingsUnitKb(kb) : l10n.settingsUnitMb(kb / 1024);
}

String formatSeconds(AppLocalizations l10n, int seconds) =>
    seconds == 0 ? l10n.settingsOff : l10n.settingsUnitSeconds(seconds);

String formatMs(AppLocalizations l10n, int ms) =>
    ms == 0 ? l10n.settingsOff : l10n.settingsUnitMs(ms);

String formatPercent(AppLocalizations l10n, int percent) =>
    l10n.settingsUnitPercent(percent);

/// A text scale as a percentage: 1.25 reads "125%".
String formatScale(AppLocalizations l10n, double scale) =>
    l10n.settingsUnitPercent((scale * 100).round());
