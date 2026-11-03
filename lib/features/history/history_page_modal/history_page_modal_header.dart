import 'package:material_ui/material_ui.dart';

import '../../../core/database/history_rows.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/context_modal/context_modal_header.dart';
import '../../../shared/widgets/playlist_cover.dart';
import '../history_side_pane.dart' show historyCollageSeed;

const double _coverSize = 64;

/// Top of the History modal: the page's collage, "History" and, once the totals
/// are read, "N listens • M songs • since date". No tap: the first row
/// takes keyboard focus.
class HistoryPageModalHeader extends StatelessWidget {
  const HistoryPageModalHeader({super.key, required this.overview});

  /// Null while the totals are not read (or failed): the line is left out.
  final HistoryOverview? overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final overview = this.overview;
    final first = overview?.firstPlayedAt;
    return ContextModalHeader(
      leading: PlaylistCover(
        coverKeys: overview?.coverKeys ?? const [],
        size: _coverSize,
        seed: historyCollageSeed,
        icon: AppIcons.history,
      ),
      lines: [
        contextModalHeaderLine(l10n.navHistory, theme.textTheme.titleMedium),
        if (overview != null)
          contextModalHeaderLine(
            [
              l10n.historyListenCount(overview.plays),
              l10n.albumsSongCount(overview.tracks),
              if (first != null)
                l10n.historySince(DateTime.fromMillisecondsSinceEpoch(first)),
            ].join(' • '),
            theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
      ],
    );
  }
}
