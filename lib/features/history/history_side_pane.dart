import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/detail_page/collage_hero_cover.dart';
import '../../shared/widgets/detail_page/detail_side_pane.dart';
import '../../shared/widgets/detail_page/play_shuffle_actions.dart';
import '../../shared/widgets/playlist_cover.dart';
import '../../shared/widgets/queue_actions_menu.dart';

/// Seed of the collage: the same arrangement in the pane, the header and the
/// backdrop.
const _collageSeed = 'history';

/// The Play / Shuffle / queue menu callbacks of the History page.
typedef HistoryPageCallbacks = ({
  VoidCallback onPlay,
  VoidCallback onShuffle,
  ValueChanged<QueueAction> onQueueAction,
});

/// Title, "N listens · since date" and the buttons, shared by the header
/// and the side pane.
class HistoryDetails extends StatelessWidget {
  const HistoryDetails({
    super.key,
    required this.overview,
    required this.callbacks,
    required this.titleStyle,
    this.actionsAtEnd = false,
  });

  /// Null while the totals are not read (or failed): only the title shows.
  final HistoryOverview? overview;
  final HistoryPageCallbacks callbacks;
  final TextStyle? titleStyle;

  /// Buttons at the right end of the column instead of the left.
  final bool actionsAtEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    // No subtitle until the totals are read: a failed or pending read must
    // not claim "0 listens".
    final overview = this.overview;
    final first = overview?.firstPlayedAt;
    final subtitle = overview == null
        ? null
        : [
            l10n.historyListenCount(overview.plays),
            if (first != null)
              l10n.historySince(DateTime.fromMillisecondsSinceEpoch(first)),
          ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.navHistory,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: actionsAtEnd
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: PlayShuffleActions(
            playLabel: l10n.albumsPlay,
            onPlay: callbacks.onPlay,
            onShuffle: callbacks.onShuffle,
            onQueueAction: callbacks.onQueueAction,
          ),
        ),
      ],
    );
  }
}

/// Left column of the History page in a wide window: the collage of the
/// latest covers as a hero card, then [HistoryDetails] (see
/// [DetailSidePane]).
class HistorySidePane extends StatelessWidget {
  const HistorySidePane({
    super.key,
    required this.overview,
    required this.callbacks,
  });

  /// Null while the totals are not read (or failed).
  final HistoryOverview? overview;
  final HistoryPageCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return DetailSidePane(
      cover: CollageHeroBackdrop(
        coverKeys: overview?.coverKeys ?? const [],
        seed: _collageSeed,
        icon: AppIcons.history,
      ),
      coverOverlay: CollageHeroCard(
        coverKeys: overview?.coverKeys ?? const [],
        seed: _collageSeed,
        icon: AppIcons.history,
      ),
      details: HistoryDetails(
        overview: overview,
        callbacks: callbacks,
        titleStyle: Theme.of(context).textTheme.headlineSmall,
        actionsAtEnd: true,
      ),
    );
  }
}

/// Header of the History page in a narrow window: a collage beside
/// [HistoryDetails]. A wide window shows [HistorySidePane] instead.
class HistoryHeader extends StatelessWidget {
  const HistoryHeader({
    super.key,
    required this.overview,
    required this.callbacks,
  });

  /// Null while the totals are not read (or failed).
  final HistoryOverview? overview;
  final HistoryPageCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
      child: Row(
        children: [
          PlaylistCover(
            coverKeys: overview?.coverKeys ?? const [],
            size: 120,
            seed: _collageSeed,
            icon: AppIcons.history,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: HistoryDetails(
              overview: overview,
              callbacks: callbacks,
              titleStyle: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ],
      ),
    );
  }
}
