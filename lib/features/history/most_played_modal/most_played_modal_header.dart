import 'package:material_ui/material_ui.dart';

import '../../../core/database/history_rows.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/context_modal/context_modal_header.dart';

const double _tileSize = 64;

/// Top of the Most played modal: a ranking tile, "Most played", the range
/// text and, once the totals were read, "M songs • N listens". No tap: the
/// first row takes keyboard focus.
class MostPlayedModalHeader extends StatelessWidget {
  const MostPlayedModalHeader({
    super.key,
    required this.rangeText,
    required this.totals,
  });

  final String rangeText;

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
      leading: SizedBox.square(
        dimension: _tileSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(AppIcons.mostPlayed, size: 32, color: colors.primary),
        ),
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
