import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/context_modal/context_modal_header.dart';
import 'history_day_modal_data.dart';

const double _tileSize = 64;

/// Top of the Day modal: a calendar tile, "Today", "Yesterday" or the
/// weekday, the full date, and "N listens • M songs • listened T". No tap:
/// the first row takes keyboard focus.
class HistoryDayModalHeader extends StatelessWidget {
  const HistoryDayModalHeader({
    super.key,
    required this.data,
    required this.now,
  });

  final HistoryDayModalData data;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final quiet = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return ContextModalHeader(
      leading: SizedBox.square(
        dimension: _tileSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(AppIcons.calendar, size: 32, color: colors.primary),
        ),
      ),
      lines: [
        contextModalHeaderLine(
          data.title(l10n, now),
          theme.textTheme.titleMedium,
        ),
        contextModalHeaderLine(l10n.historyDayDate(data.day), quiet),
        contextModalHeaderLine(data.statsLine(l10n), quiet),
      ],
    );
  }
}
