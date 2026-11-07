import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/database/library_startup.dart';
import '../../../../../core/database/lyric_translation_queries.dart';
import '../../../../../core/lyrics_translation/queue_translation_choice.dart';
import '../../../../../core/lyrics_translation/translation_scope.dart';
import '../../../../../core/lyrics_translation/translation_scope_providers.dart';
import '../../../../../core/lyrics_translation/translation_service_names.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/icons/app_icons.dart';
import '../../../../../shared/translation_service_name.dart';
import '../../../../../shared/widgets/app_snack_bar.dart';
import '../../../../../shared/widgets/marquee_text.dart';

final _log = Logger('translation');

/// Pause before an overflowing subtitle starts scrolling.
const Duration _rowMarqueeDelay = Duration(milliseconds: 300);

/// The "Use the default for this song / the queue" row under the service
/// row: drops the own choice that decides the song's service now.
///
/// [scope] is the winning tier ([TranslationScope.song] or
/// [TranslationScope.queue]); [hash] the lyrics content hash of the song.
/// The subtitle names where the song lands, computed by the same rule as the
/// choice itself with that tier removed. Saved translations are not touched;
/// the controller resolves the song again.
class TranslationUseDefaultRow extends ConsumerWidget {
  const TranslationUseDefaultRow({
    super.key,
    required this.scope,
    required this.hash,
  }) : assert(scope != TranslationScope.all);

  final TranslationScope scope;
  final String hash;

  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    if (scope == TranslationScope.queue) {
      ref.read(queueTranslationChoiceProvider.notifier).clear();
      return;
    }
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failedText = context.l10n.lyricsTranslationScopeSongSaveFailed;
    try {
      await db.setSongTranslationService(hash, null, chosenAt: null);
    } on Object catch (error) {
      _log.warning('removing the song translation service failed: $error');
      messenger?.showSnackBar(
        appSnackBar(kind: AppSnackBarKind.error, title: failedText),
      );
    }
  }

  String? _subtitle(
    AppLocalizations l10n,
    Map<String, TranslationPluginInfo> plugins,
    TranslationChoice? next,
  ) {
    if (next == null) return null;
    final service = next.service;
    final name = service == null
        ? l10n.translationServiceNotSelected
        : translationServiceName(l10n, plugins, service);
    if (scope == TranslationScope.queue) {
      return l10n.lyricsTranslationModalUseDefaultQueueTo(name);
    }
    return next.scope == TranslationScope.queue
        ? l10n.lyricsTranslationModalUseDefaultSongToQueue
        : l10n.lyricsTranslationModalUseDefaultSongTo(name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final plugins = ref.watch(translationPluginInfosProvider);
    final subtitle = _subtitle(
      l10n,
      plugins,
      translationChoiceWithout(ref.watch, hash, scope),
    );
    return Semantics(
      container: true,
      button: true,
      child: InkWell(
        onTap: () => unawaited(_apply(context, ref)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 16, 6),
            child: Row(
              children: [
                Icon(AppIcons.undo, color: colors.onSurfaceVariant),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MarqueeText(
                        text: scope == TranslationScope.queue
                            ? l10n.lyricsTranslationModalUseDefaultQueue
                            : l10n.lyricsTranslationModalUseDefaultSong,
                        startDelay: _rowMarqueeDelay,
                        style: theme.textTheme.bodyLarge,
                      ),
                      if (subtitle != null)
                        MarqueeText(
                          text: subtitle,
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
    );
  }
}
