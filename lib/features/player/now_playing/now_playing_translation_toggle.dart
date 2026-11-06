import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics_translation/translation_service_choices.dart';
import '../../../core/lyrics_translation/translation_service_resolution.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../shared/translation_notice_dialog.dart';

/// Toggles lyrics translation from a shortcut, a secondary tap, or the
/// translation modal switch: turning it off always works; turning it on needs
/// [hasLyrics] and, the first time for a service, the network notice (opened
/// on [context]). When no service is selected and the plugin records are
/// ready, [openModal] is called instead.
void quickToggleLyricsTranslation(
  BuildContext context,
  WidgetRef ref, {
  required bool hasLyrics,
  VoidCallback? openModal,
}) {
  final prefs = ref.read(settingsProvider).translation;
  // The service a request would go to; null while the plugin list loads.
  final effective = ref.read(effectiveTranslationServiceProvider);
  if (prefs.show && (effective == null || !needsNoticeFor(prefs, effective))) {
    ref.read(settingsProvider.notifier).toggleLyricsTranslation();
  } else if (hasLyrics && effective != null) {
    unawaited(enableTranslationWithNotice(context, ref, effective));
  } else if (hasLyrics) {
    final choices = ref.read(translationServiceChoicesProvider);
    if (choices.ready) {
      openModal?.call();
    }
  }
}
