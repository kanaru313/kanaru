import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'coming_soon_rows.dart';

/// Lyrics options, in the playback section. Not wired yet: whether lyrics
/// embedded in the file win over a lyrics file, shown from the saved value.
class LyricsSettingRows extends ConsumerWidget {
  const LyricsSettingRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final preferEmbedded = ref.watch(
      settingsProvider.select((s) => s.playback.preferEmbeddedLyrics),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComingSoonSwitchRow(
          title: l10n.settingsPreferEmbeddedLyrics,
          subtitle: l10n.settingsPreferEmbeddedLyricsHint,
          value: preferEmbedded,
        ),
      ],
    );
  }
}
