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
            excludeSemantics: true,
            child: Tooltip(
              message: l10n.separatorsPage(i + 1, count),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(i),
                  // A roomy hit area around the tiny indicator.
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
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
          ),
      ],
    );
  }
}
