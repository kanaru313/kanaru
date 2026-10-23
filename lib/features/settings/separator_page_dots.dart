import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

/// Pagination dots under a paged list: a 6 px dot per page, a 16 x 6 bar for
/// the current one. Each dot is a button that opens its page.
class SeparatorPageDots extends StatelessWidget {
  const SeparatorPageDots({
    super.key,
    required this.count,
    required this.selected,
    required this.onSelect,
  });

  final int count;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Semantics(
            button: true,
            selected: i == selected,
            label: l10n.separatorsPage(i + 1, count),
            // The tap is on the node itself: a screen reader can open the
            // page, and the button inside is left out of the tree.
            onTap: () => onSelect(i),
            excludeSemantics: true,
            child: Tooltip(
              message: l10n.separatorsPage(i + 1, count),
              // A real button: Tab reaches it, Enter and Space open the page.
              child: InkResponse(
                onTap: () => onSelect(i),
                radius: 16,
                mouseCursor: SystemMouseCursors.click,
                // A roomy hit area around the tiny indicator.
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 250),
                    curve: Curves.easeOutQuart,
                    width: i == selected ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == selected
                          ? colors.primary
                          : colors.onSurfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(
                        i == selected ? 4 : 3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
