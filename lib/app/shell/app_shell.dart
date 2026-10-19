import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/player/player_bar.dart';
import 'app_destination.dart';
import 'navigation_history.dart';
import 'sidebar/sidebar.dart';
import 'sidebar/sidebar_toggle.dart';
import 'top_bar.dart';

/// Window width below which the sidebar moves into a drawer.
const _sidebarBreakpoint = 720.0;

/// App frame around every top-level page: sidebar on the left, top bar above
/// the page, player bar along the bottom while something is queued. On narrow
/// windows the sidebar opens as a drawer instead.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _select(AppDestination destination) {
    final index = destination.index;
    // Selecting the current destination again returns to its root page.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  /// Mouse back/forward side buttons move through the history.
  void _onPointerDown(PointerDownEvent event, NavigationHistory history) {
    if (event.buttons & kBackMouseButton != 0) history.back();
    if (event.buttons & kForwardMouseButton != 0) history.forward();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= _sidebarBreakpoint;
    final selected = AppDestination.values[navigationShell.currentIndex];
    final history = ref.read(navigationHistoryProvider.notifier);

    final page = Expanded(child: navigationShell);
    // Spans the full width, below the sidebar too, with its own border on
    // top. Hidden with nothing to play.
    final playerBar = ref.watch(playerBarVisibleProvider)
        ? const PlayerBar()
        : null;

    return Listener(
      onPointerDown: (event) => _onPointerDown(event, history),
      child: wide
          ? Scaffold(
              bottomNavigationBar: playerBar,
              body: Row(
                children: [
                  _CollapsibleSidebar(
                    expanded: ref.watch(sidebarExpandedProvider),
                    child: Sidebar(selected: selected, onSelected: _select),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Column(children: [const TopBar(), page]),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: SidebarToggle(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Scaffold(
              bottomNavigationBar: playerBar,
              drawer: Builder(
                builder: (context) => Drawer(
                  width: sidebarWidth,
                  child: Sidebar(
                    selected: selected,
                    onSelected: (destination) {
                      Navigator.of(context).pop();
                      _select(destination);
                    },
                  ),
                ),
              ),
              body: Builder(
                builder: (context) => Column(
                  children: [
                    TopBar(onMenuPressed: Scaffold.of(context).openDrawer),
                    page,
                  ],
                ),
              ),
            ),
    );
  }
}

/// Animates the sidebar (and its divider) between full width and the icon
/// rail. The sidebar picks its layout from the width it gets.
class _CollapsibleSidebar extends StatelessWidget {
  const _CollapsibleSidebar({required this.expanded, required this.child});

  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      width: (expanded ? sidebarWidth : sidebarCompactWidth) + 1,
      child: Row(
        children: [
          Expanded(child: child),
          const VerticalDivider(width: 1),
        ],
      ),
    );
  }
}
