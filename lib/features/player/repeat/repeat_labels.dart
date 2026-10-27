import '../../../core/player/repeat_mode.dart';
import '../../../l10n/app_localizations.dart';

/// Whether a counted repeat runs ([times] above 0). The repeat UI shows it
/// instead of the base mode.
bool isCounting(int times) => times > 0;

/// Text of a repeat mode, for menu items and the button tooltip. [times] is
/// the number a counted repeat stands for, used only when [counted] is true.
String repeatModeLabel(
  AppLocalizations l10n,
  RepeatMode mode, {
  bool counted = false,
  int times = 0,
}) {
  if (counted) return l10n.playerRepeatTimes(times);
  return switch (mode) {
    RepeatMode.off => l10n.playerRepeatOff,
    RepeatMode.one => l10n.playerRepeatOne,
    RepeatMode.all => l10n.playerRepeatAll,
    RepeatMode.allShuffled => l10n.playerRepeatAllShuffled,
  };
}
