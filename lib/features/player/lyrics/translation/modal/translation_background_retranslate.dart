import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics_translation/lyrics_translation_controller.dart';
import '../../../../../core/lyrics_translation/translation_jobs.dart';
import '../../../../../core/lyrics_translation/translation_service_choices.dart';
import '../../../../../core/lyrics_translation/translation_service_names.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/translation_service_name.dart';
import '../../../../../shared/widgets/app_snack_bar.dart';
import '../lyrics_translation_labels.dart';

/// Starts a forced retranslate on [controller], pops the modal on [navigator]
/// immediately, and shows a success snackbar on [messenger] when the job
/// finishes with [TranslationJobStatus.saved].
///
/// Every handle needed after the modal closes is passed in up front so nothing
/// reads a disposed modal context or ref after the `await`.
Future<void> retranslateInBackground({
  required NavigatorState navigator,
  required LyricsTranslationController controller,
  required ScaffoldMessengerState? messenger,
  required String successText,
}) async {
  final pending = controller.retranslate();
  if (navigator.canPop()) {
    navigator.pop();
  }
  final status = await pending;
  if (status?.saved != null && messenger != null && messenger.mounted) {
    messenger.showSnackBar(
      appSnackBar(kind: AppSnackBarKind.success, title: successText),
    );
  }
}

/// Captures the navigator, controller and localized service name from the open
/// modal [context] and [ref], then runs [retranslateInBackground].
///
/// [messenger] is the one captured from the context that opened the modal; with
/// none, or with no selected service to name, no snackbar is shown.
Future<void> startBackgroundRetranslate(
  BuildContext context,
  WidgetRef ref, {
  required String appLang,
  ScaffoldMessengerState? messenger,
}) {
  final l10n = context.l10n;
  final navigator = Navigator.of(context);
  final controller = ref.read(lyricsTranslationProvider(appLang).notifier);
  // The playing song's resolved service; the default while that is not known.
  final selected =
      translationInfoOf(ref.read(lyricsTranslationProvider(appLang)))
          ?.choice
          ?.service ??
      ref.read(translationServiceChoicesProvider).selected;
  final plugins = ref.read(translationPluginInfosProvider);
  final serviceName = selected == null
      ? null
      : translationServiceName(l10n, plugins, selected);
  return retranslateInBackground(
    navigator: navigator,
    controller: controller,
    messenger: serviceName == null ? null : messenger,
    successText: serviceName == null
        ? ''
        : l10n.lyricsTranslationRetranslated(serviceName),
  );
}
