import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/lyrics_translation/translation_scope.dart';
import '../../../../../core/lyrics_translation/translation_service.dart';
import '../../../../../l10n/l10n.dart';
import 'ai_tune_save_target.dart';
import 'ai_tune_scoped_writes.dart';

/// The scope segments of the tune modal that cannot be chosen now, with the
/// reason as the tooltip: song and queue while translated lyrics are off, the
/// queue while it is empty.
Map<TranslationScope, String> aiTuneScopeLocks(
  AppLocalizations l10n, {
  required bool show,
  required bool queueEmpty,
}) => {
  if (!show) ...{
    TranslationScope.song: l10n.lyricsTranslationScopeSongLockedOff,
    TranslationScope.queue: l10n.lyricsTranslationScopeSongLockedOff,
  } else if (queueEmpty)
    TranslationScope.queue: l10n.lyricsTranslationScopeQueueLockedEmpty,
};

/// The target for [scope]; a locked scope falls back to all songs.
AiTuneSaveTarget aiTuneTargetFor({
  required TranslationScope selected,
  required Map<TranslationScope, String> locked,
  required ProviderContainer container,
  required TranslationServiceId service,
  required String hash,
  required AiTuneScopedWrites writes,
}) => AiTuneSaveTarget(
  scope: locked.containsKey(selected) ? TranslationScope.all : selected,
  container: container,
  service: service,
  hash: hash,
  writes: writes,
);
