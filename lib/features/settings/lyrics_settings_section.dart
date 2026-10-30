import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'lyrics_setting_rows.dart';
import 'lyrics_translation_setting_rows.dart';
import 'settings_section.dart';

/// Everything about lyrics in one place: which lyrics to prefer, the online
/// lookup and its permission, saved lyrics, and lyrics translation.
class LyricsSettingsSection extends StatelessWidget {
  const LyricsSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: context.l10n.settingsLyrics,
      children: const [LyricsSettingRows(), LyricsTranslationSettingRows()],
    );
  }
}
