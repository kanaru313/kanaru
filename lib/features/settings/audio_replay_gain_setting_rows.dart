import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'setting_choice.dart';
import 'setting_row.dart';
import 'settings_number_presets.dart';

/// Preamp values the dropdown offers, in dB.
const replayGainPreampPresetsDb = [
  -15.0, -12.0, -9.0, -6.0, -3.0, 0.0, 3.0, 6.0, 9.0, 12.0, 15.0, //
];

/// A preamp for display: `+3`, `0`, `−3` (a real minus sign), one decimal
/// only for a value typed into the settings file.
String formatDb(double db) {
  if (db == 0) return '0';
  final text = db.abs() == db.abs().roundToDouble()
      ? db.abs().toStringAsFixed(0)
      : db.abs().toStringAsFixed(1);
  return db > 0 ? '+$text' : '−$text';
}

/// ReplayGain rows: the mode, the preamp and clipping protection. Changes
/// reach the engine at once. The preamp and clipping rows are shown dimmed
/// while the mode is off, with the values that will apply when it is on.
class ReplayGainSettingRows extends ConsumerWidget {
  const ReplayGainSettingRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = ref.watch(settingsProvider.select((s) => s.playback));
    final settings = ref.read(settingsProvider.notifier);
    final on = p.replayGainMode != ReplayGainMode.off;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow(
          title: l10n.settingsAudioReplayGain,
          subtitle: l10n.settingsAudioReplayGainHint,
          control: (compact) => SettingChoice<ReplayGainMode>(
            compact: compact,
            selected: p.replayGainMode,
            options: [
              SettingOption(
                value: ReplayGainMode.off,
                label: l10n.replayGainModeOff,
              ),
              SettingOption(
                value: ReplayGainMode.track,
                label: l10n.replayGainModeTrack,
              ),
              SettingOption(
                value: ReplayGainMode.album,
                label: l10n.replayGainModeAlbum,
              ),
              SettingOption(
                value: ReplayGainMode.auto,
                label: l10n.replayGainModeAuto,
              ),
            ],
            onSelected: (mode) =>
                settings.setPlayback(p.copyWith(replayGainMode: mode)),
          ),
        ),
        SettingRow.single(
          title: l10n.settingsAudioReplayGainPreamp,
          subtitle: l10n.settingsAudioReplayGainPreampHint,
          control: SettingDropdown<double>(
            enabled: on,
            selected: p.replayGainPreampDb,
            options: presetOptions(
              replayGainPreampPresetsDb,
              p.replayGainPreampDb,
              (db) => l10n.settingsAudioDecibels(formatDb(db)),
            ),
            onSelected: (db) =>
                settings.setPlayback(p.copyWith(replayGainPreampDb: db)),
          ),
        ),
        SettingRow.single(
          title: l10n.settingsAudioPreventClipping,
          subtitle: l10n.settingsAudioPreventClippingHint,
          control: Switch(
            value: p.replayGainPreventClipping,
            onChanged: on
                ? (value) => settings.setPlayback(
                    p.copyWith(replayGainPreventClipping: value),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
