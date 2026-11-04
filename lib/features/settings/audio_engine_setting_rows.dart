import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'audio_output_device_setting_rows.dart';
import 'audio_replay_gain_setting_rows.dart';
import 'coming_soon_rows.dart';
import 'settings_number_presets.dart';

/// Audio Engine options: output device, ReplayGain, gapless, and crossfade.
/// (Fade in and fade out are located in Settings › Playback).
class AudioEngineSettingRows extends ConsumerWidget {
  const AudioEngineSettingRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = ref.watch(settingsProvider.select((s) => s.playback));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AudioOutputDeviceSettingRow(),
        const ReplayGainSettingRows(),
        ComingSoonSwitchRow(
          title: l10n.settingsGapless,
          subtitle: l10n.settingsGaplessHint,
          value: p.gapless,
        ),
        ComingSoonDropdownRow<int>(
          title: l10n.settingsCrossfade,
          subtitle: l10n.settingsCrossfadeHint,
          options: presetOptions(
            crossfadePresetsSeconds,
            p.crossfadeSeconds,
            (s) => formatSeconds(l10n, s),
          ),
          selected: p.crossfadeSeconds,
        ),
      ],
    );
  }
}
