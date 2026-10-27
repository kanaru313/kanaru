import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';

/// The bar that starts a day: its date, how many distinct songs the day has
/// and a menu button. Opaque, so it can sit over the rows scrolling under it
/// as the pinned bar. The same widget draws the bar in the list and the
/// pinned copy.
class HistoryDayBar extends StatelessWidget {
  const HistoryDayBar({
    super.key,
    required this.day,
    required this.tracks,
    required this.height,
    required this.onMenu,
  });

  final DateTime day;

  /// Distinct songs played that day.
  final int tracks;
  final double height;

  /// The menu button was pressed; the position (global) is the button's
  /// bottom start corner.
  final ValueChanged<Offset> onMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border(bottom: BorderSide(color: colors.outlineVariant)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 16, 0),
          child: Row(
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: l10n.historyDayDate(day),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: ' • ${l10n.albumsSongCount(tracks)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              Builder(
                // The tooltip stays short; the label says which day it is for.
                builder: (context) => Semantics(
                  label: '${l10n.historyDayMenu}, ${l10n.historyDayDate(day)}',
                  child: IconButton(
                    icon: const Icon(AppIcons.moreHoriz),
                    iconSize: 20,
                    tooltip: l10n.historyDayMenu,
                    onPressed: () {
                      final box = context.findRenderObject()! as RenderBox;
                      onMenu(box.localToGlobal(Offset(0, box.size.height)));
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
