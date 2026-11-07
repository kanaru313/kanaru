import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/database/library_startup.dart';
import '../../../../../core/database/lyric_translation_queries.dart';
import '../../../../../core/lyrics_translation/queue_translation_choice.dart';
import '../../../../../core/lyrics_translation/translation_scope.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/icons/app_icons.dart';
import '../../../../../shared/widgets/app_snack_bar.dart';
import '../../../../../shared/widgets/marquee_text.dart';

final _log = Logger('translation');

/// A song write is in flight: further taps on the row are ignored.
bool _writing = false;

/// Pause before an overflowing label starts scrolling.
const Duration _rowMarqueeDelay = Duration(milliseconds: 300);

/// The tier whose own choice the "Use the default" row can drop, or null when
/// there is none: [winning] is the tier that decides the song's service now,
/// [hash] the lyrics content hash. A song's choice needs a library database to
/// be removed.
TranslationScope? useDefaultTier(
  WidgetRef ref, {
  required TranslationScope? winning,
  required String? hash,
}) {
  if (hash == null) return null;
  if (winning == TranslationScope.queue) return winning;
  if (winning == TranslationScope.song &&
      ref.read(libraryDatabaseProvider) != null) {
    return winning;
  }
  return null;
}

/// Drops the own choice of [scope] ([TranslationScope.song] or
/// [TranslationScope.queue]) that decides the song's service now, then closes
/// the service picker [pickerContext] sits in. Saved translations are not
/// touched; the controller resolves the song again.
///
/// * song: removes the service, tune and stamp of the song `hash`; the target
///   and the note stay. A failed write shows a snackbar and the choice stays.
/// * queue: clears the queue's choice.
Future<void> applyUseDefault(
  BuildContext pickerContext,
  WidgetRef ref, {
  required TranslationScope scope,
  required String hash,
}) async {
  assert(scope != TranslationScope.all);
  final navigator = Navigator.of(pickerContext);
  final route = ModalRoute.of(pickerContext);
  // Pops only the picker this tap came from, and only while it is on top.
  void closePicker() {
    if (route?.isCurrent == true) navigator.pop();
  }

  if (scope == TranslationScope.queue) {
    ref.read(queueTranslationChoiceProvider.notifier).clear();
    closePicker();
    return;
  }
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) {
    // Not reachable from the picker (the row needs a database), but never
    // leave a dead row open.
    closePicker();
    return;
  }
  if (_writing) return;
  _writing = true;
  final messenger = ScaffoldMessenger.maybeOf(pickerContext);
  final failedText = pickerContext.l10n.lyricsTranslationScopeSongSaveFailed;
  try {
    await db.setSongTranslationService(hash, null, chosenAt: null);
  } on Object catch (error) {
    _log.warning('removing the song translation service failed: $error');
    messenger?.showSnackBar(
      appSnackBar(kind: AppSnackBarKind.error, title: failedText),
    );
  } finally {
    _writing = false;
  }
  closePicker();
}

/// The "Use the default for this song / the queue" action row at the end of
/// the translation service picker, before the "get more plugins" row. It is
/// an action, not an option: no check mark. The song row warns that the
/// song's tune goes too; the queue row has no second line.
class TranslationUseDefaultRow extends StatelessWidget {
  const TranslationUseDefaultRow({
    super.key,
    required this.scope,
    required this.onTap,
  }) : assert(scope != TranslationScope.all);

  final TranslationScope scope;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isQueue = scope == TranslationScope.queue;
    return Semantics(
      container: true,
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.undo, color: colors.onSurfaceVariant),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MarqueeText(
                            text: isQueue
                                ? l10n.lyricsTranslationModalUseDefaultQueue
                                : l10n.lyricsTranslationModalUseDefaultSong,
                            startDelay: _rowMarqueeDelay,
                            style: theme.textTheme.bodyLarge,
                          ),
                          if (!isQueue)
                            MarqueeText(
                              text: l10n
                                  .lyricsTranslationModalUseDefaultSongDrops,
                              startDelay: _rowMarqueeDelay,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
