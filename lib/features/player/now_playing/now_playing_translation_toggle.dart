import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics_translation/translation_service.dart';
import '../../../core/lyrics_translation/translation_service_choices.dart';
import '../../../core/lyrics_translation/translation_service_resolution.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../shared/translation_notice_dialog.dart';

/// Toggles lyrics translation from a shortcut, a secondary tap, or the
/// translation modal switch: turning it off always works; turning it on needs
/// [hasLyrics] and, the first time for a service, the network notice (opened
/// on [context]). When no service is selected and the plugin records are
/// ready, [openModal] is called instead.
///
/// Turning on only ever enables the default service; it never changes the
/// default. [songService], the service the playing song resolves to, is
/// asked about too when it differs from the default and was not accepted yet;
/// cancelling that question still turns translation on with the default.
void quickToggleLyricsTranslation(
  BuildContext context,
  WidgetRef ref, {
  required bool hasLyrics,
  VoidCallback? openModal,
  TranslationServiceId? songService,
}) {
  final prefs = ref.read(settingsProvider).translation;
  // The default service, which a request would use without a choice of the
  // song's own; null while the plugin list loads.
  final effective = ref.read(effectiveTranslationServiceProvider);
  // What the song uses decides whether translation counts as on: a song
  // whose own service was not accepted yet shows the notice state.
  final current = songService ?? effective;
  if (prefs.show && (current == null || !needsNoticeFor(prefs, current))) {
    ref.read(settingsProvider.notifier).toggleLyricsTranslation();
  } else if (hasLyrics && effective != null) {
    unawaited(_enable(context, ref, effective, songService));
  } else if (hasLyrics) {
    final choices = ref.read(translationServiceChoicesProvider);
    if (choices.ready) {
      openModal?.call();
    }
  }
}

/// Asks the notice of the default (and of the song's own service when it
/// needs one), then enables translation with the default in one write.
Future<void> _enable(
  BuildContext context,
  WidgetRef ref,
  TranslationServiceId defaultService,
  TranslationServiceId? songService,
) async {
  // Taken before the dialogs open, so Continue applies even when the caller
  // left the tree meanwhile.
  final settings = ref.read(settingsProvider.notifier);
  if (!await confirmTranslationNotice(context, ref, defaultService)) return;
  var acknowledgeSong = false;
  if (songService != null && songService != defaultService && context.mounted) {
    acknowledgeSong = await confirmTranslationNotice(context, ref, songService);
  }
  settings.enableTranslation(defaultService);
  if (acknowledgeSong) settings.acknowledgeTranslationNotice(songService!);
}
