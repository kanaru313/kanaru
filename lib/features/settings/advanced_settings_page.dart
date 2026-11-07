import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/settings_routes.dart';
import 'audio_engine_setting_rows.dart';
import 'danger_zone_setting_rows.dart';
import 'log_folder_setting_row.dart';
import 'privacy_network_setting_rows.dart';
import 'settings_focus.dart';
import 'settings_page_scaffold.dart';
import 'settings_section.dart';
import 'translation_scope_precedence_setting_row.dart';

/// Settings › Advanced: Audio engine, Privacy & network, Diagnostics,
/// Lyrics translation, and Danger zone.
class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({super.key, this.focus});

  /// The group or row a link asked for.
  final SettingsAnchor? focus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SettingsPageScaffold(
      title: l10n.settingsAdvanced,
      focus: focus,
      children: [
        SettingsFocusTarget(
          anchor: SettingsAnchor.advancedAudio,
          child: SettingsSection(
            title: l10n.settingsGroupAudioEngine,
            children: const [AudioEngineSettingRows()],
          ),
        ),
        SettingsSection(
          title: l10n.settingsGroupPrivacyNetwork,
          children: const [PrivacyNetworkSettingRows()],
        ),
        SettingsSection(
          title: l10n.settingsGroupDiagnostics,
          children: const [LogFolderSettingRow()],
        ),
        SettingsSection(
          title: l10n.settingsGroupLyricsTranslation,
          children: const [TranslationScopePrecedenceSettingRow()],
        ),
        SettingsFocusTarget(
          anchor: SettingsAnchor.advancedDanger,
          child: SettingsSection(
            title: l10n.settingsGroupDangerZone,
            children: const [DangerZoneSettingRows()],
          ),
        ),
      ],
    );
  }
}
