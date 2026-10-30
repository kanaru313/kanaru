import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/settings/settings_provider.dart';
import '../../../shared/translation_notice_dialog.dart';

/// The `T` key: turning lyrics translation off always works; turning it on
/// needs [hasLyrics] and, the first time for a service, the network notice
/// (opened on [context]).
void toggleLyricsTranslationByKey(
  BuildContext context,
  WidgetRef ref, {
  required bool hasLyrics,
}) {
  final prefs = ref.read(settingsProvider).translation;
  if (prefs.show && !prefs.needsNotice) {
    ref.read(settingsProvider.notifier).toggleLyricsTranslation();
  } else if (hasLyrics) {
    unawaited(enableTranslationWithNotice(context, ref, prefs.service));
  }
}
