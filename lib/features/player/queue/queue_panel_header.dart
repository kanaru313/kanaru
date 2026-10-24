import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../playback_controls.dart';

/// Top of the queue panel, in two rows. The first has the title and, in the
/// side sheet, the close button. The second has the [summary] line on the
/// left and, on the right, the filter and "jump to current" buttons plus an
/// overflow menu with "save as playlist" and "clear queue".
class QueuePanelHeader extends StatelessWidget {
  const QueuePanelHeader({
    super.key,
    required this.summary,
    required this.filterOpen,
    required this.onFilter,
    this.filterFocus,
    this.onSave,
    required this.onClear,
    required this.onShowCurrent,
    this.onClose,
    this.showTitle = true,
  });

  /// Track count and time left; the parent supplies a widget that follows
  /// the playback by itself, so the header does not rebuild on every tick.
  final Widget summary;

  /// Whether the filter box is shown below the header.
  final bool filterOpen;

  /// Opens the filter box, or closes it when it is open.
  final VoidCallback onFilter;

  /// Focus of the filter button, so Esc in the box can return to it.
  final FocusNode? filterFocus;

  /// Saves the queue as a playlist; `null` greys the menu item out (no
  /// library).
  final VoidCallback? onSave;

  /// `null` greys the menu item out: nothing left to clear.
  final VoidCallback? onClear;
  final VoidCallback onShowCurrent;

  /// `null` hides the close button (the narrow page has nothing to close).
  final VoidCallback? onClose;

  /// Whether the first row (title and close button) is shown. A panel that
  /// sits under a title of its own hides it.
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, showTitle ? 16 : 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle)
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.queueTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (onClose != null)
                  _NamedIconButton(
                    icon: AppIcons.closeRounded,
                    label: l10n.queueClose,
                    onPressed: onClose,
                  ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: DefaultTextStyle.merge(
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: summary,
                ),
              ),
              _NamedIconButton(
                focusNode: filterFocus,
                icon: AppIcons.search,
                label: l10n.inPageSearchOpen,
                selected: filterOpen,
                onPressed: onFilter,
              ),
              _NamedIconButton(
                icon: AppIcons.locateCurrent,
                label: l10n.queueShowCurrent,
                onPressed: onShowCurrent,
              ),
              _OverflowMenu(onSave: onSave, onClear: onClear),
            ],
          ),
        ],
      ),
    );
  }
}

/// The `⋮` button and its menu. The playing track stays when the queue is
/// cleared, so clearing needs no confirmation.
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.onSave, required this.onClear});

  final VoidCallback? onSave;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(AppIcons.saveQueue),
          onPressed: onSave,
          child: Text(l10n.queueSaveAsPlaylist),
        ),
        MenuItemButton(
          leadingIcon: const Icon(AppIcons.clearAll),
          onPressed: onClear,
          child: Text(l10n.queueClear),
        ),
      ],
      builder: (context, controller, _) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        return _NamedIconButton(
          icon: AppIcons.more,
          label: l10n.queueMoreActions,
          selected: controller.isOpen,
          expanded: controller.isOpen,
          onPressed: toggle,
        );
      },
    );
  }
}

/// Icon button with an explicit accessible name: a tooltip alone gives
/// assistive technology none. The wrapper replaces the button's own
/// semantics, so the name is announced once; the tooltip stays for the mouse.
class _NamedIconButton extends StatelessWidget {
  const _NamedIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.focusNode,
    this.selected = false,
    this.expanded,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;

  /// Drawn and announced as on (the filter is open, the menu is open).
  final bool selected;

  /// For a button that opens a menu: whether the menu is open.
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      enabled: onPressed != null,
      selected: selected,
      expanded: expanded,
      onTap: onPressed,
      excludeSemantics: true,
      child: IconButton(
        focusNode: focusNode,
        icon: Icon(icon),
        iconSize: playerIconSize,
        tooltip: label,
        isSelected: selected,
        onPressed: onPressed,
      ),
    );
  }
}
