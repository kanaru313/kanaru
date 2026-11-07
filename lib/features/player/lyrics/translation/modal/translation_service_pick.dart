import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/database/library_startup.dart';
import '../../../../../core/database/lyric_translation_queries.dart';
import '../../../../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../../../../core/lyrics_translation/translation_clock.dart';
import '../../../../../core/lyrics_translation/translation_scope.dart';
import '../../../../../core/lyrics_translation/translation_scope_providers.dart';
import '../../../../../core/lyrics_translation/translation_service.dart';
import '../../../../../core/lyrics_translation/translation_service_resolution.dart';
import '../../../../../core/settings/settings_provider.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/app_snack_bar.dart';

final _log = Logger('translation');

/// Songs with their own service choice that a pick for all songs would
/// replace: the choice's plugin is still installed and it is newer than the
/// default's stamp, so it can win over the default now. Read from providers
/// that are already loaded; 0 while they load.
int songsReplacedByDefault(WidgetRef ref) {
  final records = ref.read(translatePluginRecordsProvider).value;
  final overrides = ref.read(songTranslationOverridesProvider).value;
  if (records == null || overrides == null) return 0;
  final live = {
    for (final r in records) ?TranslationServiceId.tryParse(r.installId),
  };
  final allChosenAt = ref.read(settingsProvider).translation.allChosenAt;
  var count = 0;
  for (final row in overrides.values) {
    final service = TranslationServiceId.tryParse(row.service);
    final at = row.chosenAt;
    if (service == null || !live.contains(service) || at == null) continue;
    if (allChosenAt == null || at > allChosenAt) count++;
  }
  return count;
}

/// Writes the service the user picked for [scope]. [picked] is already
/// confirmed (the picker asked the network notice before closing). Nothing is
/// written when [context] left the tree meanwhile or when the choice has no
/// place to go (no song hash, no database). The stamp is read from the clock
/// here, after the confirmation, so the newest choice is the one the user
/// confirmed last.
///
/// * [TranslationScope.song]: stores the song's own service; the default and
///   its stamp stay.
/// * [TranslationScope.all]: changes the default service and stamps it. No
///   song's own choice is deleted; the ones older than the stamp stop winning.
Future<void> applyServicePick(
  BuildContext context,
  WidgetRef ref, {
  required TranslationServiceId picked,
  required TranslationScope scope,
  required String? hash,
}) async {
  if (scope == TranslationScope.queue) return;
  final db = ref.read(libraryDatabaseProvider);
  if (scope == TranslationScope.song && (hash == null || db == null)) return;
  if (!context.mounted) return;
  final clock = ref.read(translationClockProvider);
  final settings = ref.read(settingsProvider.notifier);
  if (scope == TranslationScope.song) {
    if (hash == null || db == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failedText = context.l10n.lyricsTranslationScopeSongSaveFailed;
    settings.acknowledgeTranslationNotice(picked);
    try {
      await db.setSongTranslationService(hash, picked.value, chosenAt: clock());
    } on Object catch (error) {
      _log.warning('saving the song translation service failed: $error');
      messenger?.showSnackBar(
        appSnackBar(kind: AppSnackBarKind.error, title: failedText),
      );
    }
    return;
  }
  final prefs = ref.read(settingsProvider).translation;
  if (prefs.service == null || (prefs.show && needsNoticeFor(prefs, picked))) {
    settings.enableTranslation(picked, allChosenAt: clock());
  } else {
    settings.setTranslation(
      prefs.copyWith(service: picked, allChosenAt: clock()),
    );
  }
}
