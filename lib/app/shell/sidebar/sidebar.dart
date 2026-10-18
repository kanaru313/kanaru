import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../app_destination.dart';
import '../top_bar.dart';
import '../window/window_drag_area.dart';
import 'sidebar_item.dart';
import 'sidebar_playlists_section.dart';

const sidebarWidth = 240.0;

/// Width of the collapsed sidebar, which shows icons only.
const sidebarCompactWidth = 72.0;

/// Below this width the sidebar lays out as the icon rail. Anything between
/// the two widths only happens while the collapse animation runs.
const _compactBelow = 180.0;

/// Left navigation column: app logo, grouped destinations and playlists.
/// Fills the width its parent gives it and switches to an icon-only rail
/// when that width is small.
class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.selected, required this.onSelected});

  /// Highlighted destination. Pages not in the sidebar highlight nothing.
  final AppDestination selected;
  final ValueChanged<AppDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // A slightly raised surface sets the sidebar apart from the page.
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < _compactBelow;
          final divider = Divider(
            height: 17,
            indent: compact ? 4 : 8,
            endIndent: compact ? 4 : 8,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WindowDragArea(child: _Logo(compact: compact)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  children: [
                    for (final (i, group) in sidebarGroups.indexed) ...[
                      if (i > 0) divider,
                      for (final destination in group)
                        SidebarItem(
                          icon: destination.icon,
                          selectedIcon: destination.selectedIcon,
                          label: destination.label(l10n),
                          selected: destination == selected,
                          compact: compact,
                          onTap: () => onSelected(destination),
                        ),
                    ],
                    divider,
                    SidebarPlaylistsSection(compact: compact),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = Icon(
      Icons.graphic_eq,
      color: theme.colorScheme.primary,
      size: 28,
    );

    return SizedBox(
      height: topBarHeight,
      child: compact
          ? Center(child: icon)
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                spacing: 12,
                children: [
                  icon,
                  Flexible(
                    child: Text(
                      context.l10n.appTitle,
                      overflow: TextOverflow.clip,
                      maxLines: 1,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
