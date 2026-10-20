import 'package:material_ui/material_ui.dart';

import 'sidebar_tooltip.dart';

/// One navigation row in the sidebar. The selected row gets an accent-tinted
/// background with an accent bar on its left edge. In [compact] mode (the
/// collapsed rail) only the icon is shown and the label becomes a tooltip
/// on its right.
class SidebarItem extends StatelessWidget {
  const SidebarItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final iconWidget = Icon(
      selected ? selectedIcon : icon,
      size: 22,
      color: selected ? colors.primary : colors.onSurfaceVariant,
    );

    final content = compact
        ? Center(child: iconWidget)
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              spacing: 12,
              children: [
                iconWidget,
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),
          );

    final item = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Semantics(
            selected: selected,
            button: true,
            label: compact ? label : null,
            child: SizedBox(
              height: 44,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  content,
                  if (selected)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: ColoredBox(
                        color: colors.primary,
                        child: const SizedBox(width: 3),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return compact ? SidebarTooltip(message: label, child: item) : item;
  }
}
