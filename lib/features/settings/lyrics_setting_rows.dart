import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/online_lyrics_notice_dialog.dart';
import 'online_lyrics_cache_setting_row.dart';
import 'online_lyrics_consent_setting_row.dart';
import 'setting_row.dart';

/// Lyrics options, in the Lyrics section: whether lyrics embedded in the
/// file are tried before the `.lrc` file next to it (changing it reloads the
/// playing track's lyrics), the online lookup switches and the saved online
/// lyrics.
class LyricsSettingRows extends ConsumerWidget {
  const LyricsSettingRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final playback = ref.watch(settingsProvider.select((s) => s.playback));
    final online = ref.watch(settingsProvider.select((s) => s.onlineLyrics));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow.single(
          title: l10n.settingsPreferEmbeddedLyrics,
          subtitle: l10n.settingsPreferEmbeddedLyricsHint,
          control: Switch(
            value: playback.preferEmbeddedLyrics,
            onChanged: (on) => ref
                .read(settingsProvider.notifier)
                .setPlayback(playback.copyWith(preferEmbeddedLyrics: on)),
          ),
        ),
        SettingRow.single(
          title: l10n.settingsAutoOnlineLyrics,
          subtitle: l10n.settingsAutoOnlineLyricsHint,
          control: Switch(
            // Only with the automatic consent, so a stale flag never shows
            // "on" while lookups are refused.
            value: online.autoAllowed,
            onChanged: (on) {
              final settings = ref.read(settingsProvider.notifier);
              if (!on) {
                // Consent stays: turning it on again asks nothing.
                settings.setOnlineLyrics(online.copyWith(autoFetch: false));
                return;
              }
              unawaited(
                confirmOnlineLyricsNotice(
                  Navigator.of(context, rootNavigator: true),
                  ProviderScope.containerOf(context),
                  auto: true,
                ),
              );
            },
          ),
        ),
        const OnlineLyricsConsentSettingRow(),
        const OnlineLyricsCacheSettingRow(),
      ],
    );
  }
}
