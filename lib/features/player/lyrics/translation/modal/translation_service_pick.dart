import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/database/library_startup.dart';
import '../../../../../core/database/lyric_translation_queries.dart';
import '../../../../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../../../../core/lyrics_translation/queue_translation_choice.dart';
import '../../../../../core/lyrics_translation/translation_clock.dart';
import '../../../../../core/lyrics_translation/translation_scope.dart';
import '../../../../../core/lyrics_translation/translation_scope_providers.dart';
import '../../../../../core/lyrics_translation/translation_service.dart';
import '../../../../../core/lyrics_translation/translation_service_resolution.dart';
import '../../../../../core/settings/settings_provider.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/app_snack_bar.dart';

final _log = Logger('translation');

/// What the "All songs" scope tells about songs and the queue set
/// individually: how many [songs] and whether the [queue] are affected, read
/// by [allScopeCaption].
typedef AllScopeCaption = ({
  TranslationScopePrecedence precedence,
  int songs,
  bool queue,
});

/// The counts behind the caption of the "All songs" scope, read once from
/// providers that are already loaded: both are empty while the plugin
/// records load; while only the song rows load, the song count is 0 but the
/// queue flag is already computed.
///
/// * [TranslationScopePrecedence.replaceAll]: [AllScopeCaption.songs] are
///   the songs whose own choice is installed and newer than the default's
///   stamp, so a pick for all songs would replace them; the queue counts when
///   its choice is installed and newer than the stamp too.
/// * [TranslationScopePrecedence.keepCustom]: [AllScopeCaption.songs] are
///   all songs with an installed own choice, and the queue counts when it has
///   an installed choice; they keep their service whatever the stamps.
AllScopeCaption allScopeCaption(WidgetRef ref) {
  final prefs = ref.read(settingsProvider).translation;
  final precedence = prefs.scopePrecedence;
  final records = ref.read(translatePluginRecordsProvider).value;
  final overrides = ref.read(songTranslationOverridesProvider).value;
  if (records == null) return (precedence: precedence, songs: 0, queue: false);
  final live = {
    for (final r in records) ?TranslationServiceId.tryParse(r.installId),
  };
  final keep = precedence == TranslationScopePrecedence.keepCustom;
  final allChosenAt = prefs.allChosenAt;
  bool counts(int? at) =>
      keep || (at != null && (allChosenAt == null || at > allChosenAt));
  var songs = 0;
  for (final row in overrides?.values ?? const <SongTranslationOverride>[]) {
    final service = TranslationServiceId.tryParse(row.service);
    if (service != null && live.contains(service) && counts(row.chosenAt)) {
      songs++;
    }
  }
  final queueChoice = ref.read(queueTranslationChoiceProvider);
  final queue =
      queueChoice != null &&
      live.contains(queueChoice.service) &&
      counts(queueChoice.chosenAt);
  return (precedence: precedence, songs: songs, queue: queue);
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
/// * [TranslationScope.queue]: stores the service for the queue playing now
///   (kept with the session until another queue replaces it); the default
///   and its stamp stay.
/// * [TranslationScope.all]: changes the default service and stamps it. No
///   song's or queue's own choice is deleted; with
///   [TranslationScopePrecedence.replaceAll] the ones older than the stamp
///   stop winning, with [TranslationScopePrecedence.keepCustom] they keep
///   winning.
Future<void> applyServicePick(
  BuildContext context,
  WidgetRef ref, {
  required TranslationServiceId picked,
  required TranslationScope scope,
  required String? hash,
}) async {
  final db = ref.read(libraryDatabaseProvider);
  if (scope == TranslationScope.song && (hash == null || db == null)) return;
  if (!context.mounted) return;
  final clock = ref.read(translationClockProvider);
  final settings = ref.read(settingsProvider.notifier);
  if (scope == TranslationScope.queue) {
    settings.acknowledgeTranslationNotice(picked);
    ref
        .read(queueTranslationChoiceProvider.notifier)
        .set(picked, chosenAt: clock());
    return;
  }
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
