import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/lyrics_provider_registry.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'setting_row.dart';
import 'settings_confirm_dialog.dart';

/// What the user allowed for [registration] (manual search, and automatic
/// search on top), with a button that withdraws it after a confirmation.
/// Saved lyrics stay. Off while nothing is allowed.
class OnlineLyricsConsentSettingRow extends ConsumerWidget {
  const OnlineLyricsConsentSettingRow({super.key, required this.registration});

  final LyricsProviderRegistration registration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final acknowledged = ref.watch(
      settingsProvider.select((s) => s.onlineLyrics.noticeAcknowledged),
    );
    final auto = acknowledged.contains(registration.autoConsentKey);
    final manual = acknowledged.contains(registration.consentKey);
    return SettingRow.single(
      title: l10n.settingsLyricsConsent,
      subtitle: auto
          ? l10n.settingsLyricsConsentAuto
          : manual
          ? l10n.settingsLyricsConsentManual
          : l10n.settingsLyricsConsentNone,
      control: FilledButton.tonal(
        style: settingButtonStyle(),
        onPressed: auto || manual
            ? () async {
                final notifier = ref.read(settingsProvider.notifier);
                final confirmed = await confirmDestructive(
                  context,
                  title: l10n.settingsLyricsConsentWithdrawTitle,
                  body: l10n.settingsLyricsConsentWithdrawBody,
                  confirmLabel: l10n.settingsLyricsConsentWithdraw,
                );
                if (confirmed) {
                  notifier.withdrawOnlineLyricsConsent(registration);
                }
              }
            : null,
        child: Text(
          l10n.settingsLyricsConsentWithdraw,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
