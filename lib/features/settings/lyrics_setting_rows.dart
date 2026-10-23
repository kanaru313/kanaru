import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'setting_row.dart';

/// Lyrics options, in the playback section: whether lyrics embedded in the
/// file are tried before the `.lrc` file next to it. Changing it reloads the
/// playing track's lyrics.
class LyricsSettingRows extends ConsumerWidget {
  const LyricsSettingRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final playback = ref.watch(settingsProvider.select((s) => s.playback));

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
      ],
    );
  }
}
