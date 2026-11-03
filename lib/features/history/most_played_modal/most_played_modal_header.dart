import 'package:material_ui/material_ui.dart';

import '../../../core/database/history_rows.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/context_modal/context_modal_header.dart';
import '../../../shared/widgets/playlist_cover.dart';
import '../most_played_side_pane.dart' show mostPlayedCollageSeed;

const double _coverSize = 64;

/// Top of the Most played modal: the page's collage, "Most played", the range
/// text and, once the totals were read, "M songs • N listens". No tap: the
/// first row takes keyboard focus.
class MostPlayedModalHeader extends StatelessWidget {
  const MostPlayedModalHeader({
    super.key,
    required this.rangeText,
    required this.totals,
    required this.coverKeys,
  });

  final String rangeText;

  /// The collage keys the page shows for this ranking.
  final List<String> coverKeys;

  /// Null while the range's totals were not read: the line is left out.
  final HistoryRangeSummary? totals;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final quiet = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final totals = this.totals;
    return ContextModalHeader(
      leading: PlaylistCover(
        coverKeys: coverKeys,
        size: _coverSize,
        seed: mostPlayedCollageSeed,
        icon: AppIcons.mostPlayed,
      ),
      lines: [
        contextModalHeaderLine(l10n.navMostPlayed, theme.textTheme.titleMedium),
        contextModalHeaderLine(rangeText, quiet),
        if (totals != null)
          contextModalHeaderLine(
            [
              l10n.albumsSongCount(totals.tracks),
              l10n.historyListenCount(totals.plays),
            ].join(' • '),
            quiet,
          ),
      ],
    );
  }
}
