import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'coming_soon_rows.dart';
import 'settings_number_presets.dart';

/// Playback options that are not wired yet (shown from the saved values,
/// off): lyrics, gapless, crossfade, fades, endless queue, and when a play
/// counts as a listen.
class PlaybackSettingRows extends ConsumerWidget {
  const PlaybackSettingRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = ref.watch(settingsProvider.select((s) => s.playback));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComingSoonSwitchRow(
          title: l10n.settingsPreferEmbeddedLyrics,
          subtitle: l10n.settingsPreferEmbeddedLyricsHint,
          value: p.preferEmbeddedLyrics,
        ),
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
        ComingSoonDropdownRow<int>(
          title: l10n.settingsFadeOnPlay,
          subtitle: l10n.settingsFadeOnPlayHint,
          options: presetOptions(
            fadePresetsMs,
            p.fadeOnPlayMs,
            (ms) => formatMs(l10n, ms),
          ),
          selected: p.fadeOnPlayMs,
        ),
        ComingSoonDropdownRow<int>(
          title: l10n.settingsFadeOnPause,
          subtitle: l10n.settingsFadeOnPauseHint,
          options: presetOptions(
            fadePresetsMs,
            p.fadeOnPauseMs,
            (ms) => formatMs(l10n, ms),
          ),
          selected: p.fadeOnPauseMs,
        ),
        ComingSoonSwitchRow(
          title: l10n.settingsInfiniteQueue,
          subtitle: l10n.settingsInfiniteQueueHint,
          value: p.infiniteQueue,
        ),
        // Two rows, not two controls in one: a row's control is one compact
        // width, too narrow for two dropdowns.
        ComingSoonDropdownRow<int>(
          title: l10n.settingsListenAfterTime,
          subtitle: l10n.settingsListenAfterTimeHint,
          options: presetOptions(
            listenMinutesPresets,
            p.listenThresholdMinutes,
            l10n.settingsUnitMinutes,
          ),
          selected: p.listenThresholdMinutes,
        ),
        ComingSoonDropdownRow<int>(
          title: l10n.settingsListenAfterShare,
          subtitle: l10n.settingsListenAfterShareHint,
          options: presetOptions(
            listenPercentPresets,
            p.listenThresholdPercent,
            (percent) => formatPercent(l10n, percent),
          ),
          selected: p.listenThresholdPercent,
        ),
      ],
    );
  }
}
