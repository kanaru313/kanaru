import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/lyrics_translation/translation_service.dart';
import '../core/lyrics_translation/translation_service_names.dart';
import '../core/settings/settings_provider.dart';
import '../l10n/l10n.dart';
import 'translation_service_name.dart';

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
  TranslationServiceId service,
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
  TranslationServiceId service,
) async {
  final settings = ref.read(settingsProvider.notifier);
  if (!await confirmTranslationNotice(context, ref, service)) return;
  settings.enableTranslation(service);
}

class _TranslationNoticeDialog extends ConsumerWidget {
  const _TranslationNoticeDialog(this.service);

  final TranslationServiceId service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final plugins = ref.watch(translationPluginInfosProvider);
    final name = translationServiceName(l10n, plugins, service);
    // The hosts are always listed for a plugin: that is where the lyrics go.
    final hosts = plugins[service.value]?.hosts ?? const <String>[];
    return AlertDialog(
      title: Text(l10n.translationNoticePluginTitle(name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.translationNoticePluginBody),
            const SizedBox(height: 8),
            for (final host in hosts) SelectableText(host),
          ],
        ),
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
