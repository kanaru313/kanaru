import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/indexer/indexer_providers.dart';
import '../../features/library/scan_result_snack_bar.dart';
import '../../features/player/now_playing/now_playing_open_provider.dart';
import '../../features/player/now_playing/now_playing_overlay.dart';
import '../../features/player/player_bar.dart';
import '../../features/player/queue/queue_sheet_host.dart';
import 'app_destination.dart';
import 'navigation_history.dart';
import 'sidebar/sidebar.dart';
import 'sidebar/sidebar_toggle.dart';
import 'top_bar.dart';
import 'window/desktop_window.dart';
import 'window/window_buttons.dart';
import 'window/window_drag_area.dart';

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

  /// Header of Now Playing with the window drag area and buttons, which
  /// features cannot reach themselves.
  Widget _nowPlayingTitleBar(Widget header, bool customTitleBar) {
    return WindowDragArea(
      child: Row(
        children: [
          Expanded(child: header),
          if (customTitleBar)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: WindowButtons(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Announced here, once, wherever the scan was started from (a library
    // page, Settings); the pages themselves stay mounted side by side.
    ref.listen(libraryIndexerProvider, (previous, next) {
      final snackBar = scanResultSnackBar(context, next);
      if (snackBar == null) return;
      // Queued, not replacing: a message shown right before (for example a
      // folder refused on the welcome screen) must stay readable.
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    });

    final wide = MediaQuery.sizeOf(context).width >= _sidebarBreakpoint;
    final selected = AppDestination.values[navigationShell.currentIndex];
    final nowPlayingOpen = ref.watch(nowPlayingOpenProvider);
    final customTitleBar = ref.watch(customTitleBarProvider);

    final page = Expanded(child: navigationShell);
    // Spans the full width, below the sidebar too, with its own border on
    // top. Hidden with nothing to play.
    final playerBar = ref.watch(playerBarVisibleProvider)
        ? const PlayerBar()
        : null;

    final history = ref.read(navigationHistoryProvider.notifier);
    // The mouse side buttons move through the history, unless the queue
    // sheet is open (back closes it). While Now Playing is open the shell
    // gets no pointer events; Now Playing handles them itself.
    final shell = QueueSheetHost(
      onMouseBack: history.back,
      onMouseForward: history.forward,
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

    return Stack(
      fit: StackFit.expand,
      children: [
        // Behind Now Playing nothing may take focus, be read out or run
        // animations; the page state is kept for when it closes.
        ExcludeFocus(
          excluding: nowPlayingOpen,
          child: ExcludeSemantics(
            excluding: nowPlayingOpen,
            child: IgnorePointer(
              ignoring: nowPlayingOpen,
              child: TickerMode(enabled: !nowPlayingOpen, child: shell),
            ),
          ),
        ),
        NowPlayingOverlay(
          titleBar: (header) => _nowPlayingTitleBar(header, customTitleBar),
        ),
      ],
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
