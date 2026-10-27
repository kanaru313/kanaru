import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/lyrics_translation/translation_service.dart';
import '../core/settings/settings_provider.dart';
import '../l10n/l10n.dart';

/// What [service] is called on screen (brand names, not translated).
String translationServiceName(LyricsTranslationService service) =>
    switch (service) {
      LyricsTranslationService.google => 'Google',
      LyricsTranslationService.deepl => 'DeepL',
    };

/// Makes sure the user accepted sending lyrics to [service]. Returns true at
/// once when they did before; otherwise asks and returns whether they chose
/// Continue. It writes nothing: after a true the caller changes the settings
/// (see [enableTranslationWithNotice]), and after a false nothing changes.
///
/// [context] must be mounted when this is called (the dialog opens on it);
/// it may unmount while the dialog is open.
Future<bool> confirmTranslationNotice(
  BuildContext context,
  WidgetRef ref,
  LyricsTranslationService service,
) async {
  final accepted = ref
      .read(settingsProvider)
      .translation
      .noticeAcknowledged
      .contains(service);
  if (accepted) return true;
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => _TranslationNoticeDialog(service),
  );
  return answer ?? false;
}

/// Turns translation on with [service] after [confirmTranslationNotice]:
/// selects it, records the notice as accepted and shows translations in one
/// settings write. Does nothing when the user cancels. The settings are taken
/// before the dialog opens, so Continue applies even when the caller left the
/// tree meanwhile.
Future<void> enableTranslationWithNotice(
  BuildContext context,
  WidgetRef ref,
  LyricsTranslationService service,
) async {
  final settings = ref.read(settingsProvider.notifier);
  if (!await confirmTranslationNotice(context, ref, service)) return;
  settings.enableTranslation(service);
}

class _TranslationNoticeDialog extends StatelessWidget {
  const _TranslationNoticeDialog(this.service);

  final LyricsTranslationService service;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = translationServiceName(service);
    return AlertDialog(
      title: Text(l10n.translationNoticeTitle(name)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.translationNoticeBody(name)),
          if (service == LyricsTranslationService.google) ...[
            const SizedBox(height: 12),
            Text(l10n.translationNoticeGoogleUnofficial),
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
          child: Text(l10n.translationNoticeContinue),
        ),
      ],
    );
  }
}
