import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/language_display_name.dart';
import '../../../shared/language_summaries.dart';
import '../../../shared/widgets/library_row.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../../../shared/widgets/song_card.dart';
import 'enqueue_language.dart';
import 'language_avatar.dart';

/// One language row: round avatar, name, "N songs • M min", and "Language".
class LanguageTile extends ConsumerWidget {
  const LanguageTile({
    super.key,
    required this.language,
    required this.onTap,
    this.onQueueAction,
  });

  final LanguageSummary language;
  final VoidCallback onTap;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final durationMs = language.durationMs;
    final tile = LibraryPlayableRow(
      leading: LanguageAvatar(
        languageKey: language.key,
        size: libraryRowCoverSize,
      ),
      lines: [
        languageSummaryName(l10n, language),
        joinRowDetails([
          l10n.albumsSongCount(language.songCount),
          if (durationMs != null && durationMs > 0) rowLength(l10n, durationMs),
        ]),
        l10n.settingsLanguage,
      ],
      onTap: onTap,
      onPlay: () => unawaited(playLanguage(ref, language)),
      playTooltip: l10n.albumsPlay,
      more: onQueueAction == null
          ? null
          : QueueActionsButton(onSelected: onQueueAction!),
      horizontalPadding: songCardInset,
      inkBorder: songCardShape,
    );
    return QueueActionsRegion(
      onAction: onQueueAction,
      child: SongCardFrame(child: tile),
    );
  }
}
