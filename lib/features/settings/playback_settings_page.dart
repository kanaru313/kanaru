import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/settings_routes.dart';
import 'listen_history_setting_rows.dart';
import 'lyrics_settings_section.dart';
import 'lyrics_translation_setting_rows.dart';
import 'playback_setting_rows.dart';
import 'settings_focus.dart';
import 'settings_page_scaffold.dart';
import 'settings_section.dart';

/// Settings › Playback: Playback, Lyrics (with the lyrics sources page
/// below this one) and Translation.
class PlaybackSettingsPage extends StatelessWidget {
  const PlaybackSettingsPage({super.key, this.focus});

  /// The group or row a link asked for.
  final SettingsAnchor? focus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SettingsPageScaffold(
      title: l10n.settingsPlayback,
      focus: focus,
      children: [
        SettingsSection(
          title: l10n.settingsGroupPlayback,
          children: const [PlaybackSettingRows(), ListenHistorySettingRows()],
        ),
        const SettingsFocusTarget(
          anchor: SettingsAnchor.playbackLyrics,
          child: LyricsSettingsSection(),
        ),
        SettingsFocusTarget(
          anchor: SettingsAnchor.playbackTranslation,
          child: SettingsSection(
            title: l10n.settingsGroupTranslation,
            children: const [LyricsTranslationSettingRows()],
          ),
        ),
      ],
    );
  }
}
