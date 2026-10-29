import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/lyrics/online/lyrics_provider_registry.dart';
import '../core/settings/settings_provider.dart';
import '../l10n/l10n.dart';

/// Makes sure the user accepted sending song details to [registration]'s
/// service. Returns true at once when they did before; otherwise asks and,
/// on Continue, records the consent and returns true. On Cancel nothing is
/// written and the answer is false.
///
/// [auto] asks for permission to look lyrics up without asking each time:
/// Continue turns that on (and accepts the manual search too) in one write.
/// When that consent is already recorded it turns automatic lookup on
/// without a dialog.
/// Otherwise Continue accepts only the manual search.
///
/// The dialog opens on [navigator]'s context. The settings are taken from
/// [container] before it opens, so the caller (a menu row, say) may leave
/// the tree while the dialog is open and Continue still applies. Takes no
/// `WidgetRef` for the same reason.
Future<bool> confirmOnlineLyricsNotice(
  NavigatorState navigator,
  ProviderContainer container,
  LyricsProviderRegistration registration, {
  required bool auto,
}) async {
  final settings = container.read(settingsProvider.notifier);
  final key = auto ? registration.autoConsentKey : registration.consentKey;
  final accepted = container
      .read(settingsProvider)
      .onlineLyrics
      .noticeAcknowledged
      .contains(key);
  if (accepted) {
    // Confirming auto always leaves automatic lookup on, also when the key
    // was kept while the switch was turned off. Writes nothing new then.
    if (auto) settings.enableAutoOnlineLyrics(registration);
    return true;
  }
  final answer = await showDialog<bool>(
    context: navigator.context,
    builder: (context) =>
        _OnlineLyricsNoticeDialog(registration: registration, auto: auto),
  );
  if (answer != true) return false;
  if (auto) {
    settings.enableAutoOnlineLyrics(registration);
  } else {
    settings.acknowledgeOnlineLyricsNotice(registration.consentKey);
  }
  return true;
}

class _OnlineLyricsNoticeDialog extends StatelessWidget {
  const _OnlineLyricsNoticeDialog({
    required this.registration,
    required this.auto,
  });

  final LyricsProviderRegistration registration;
  final bool auto;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        auto
            ? l10n.onlineLyricsNoticeAutoTitle
            : l10n.onlineLyricsNoticeManualTitle(registration.displayName),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.onlineLyricsNoticeBody(registration.hosts.join(', '))),
          if (auto) ...[
            const SizedBox(height: 12),
            Text(l10n.onlineLyricsNoticeAutoHint),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            auto
                ? l10n.onlineLyricsNoticeTurnOn
                : l10n.onlineLyricsNoticeSearch,
          ),
        ),
      ],
    );
  }
}
