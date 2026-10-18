import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Window width at which the bottom navigation bar becomes a side rail.
const _railBreakpoint = 600.0;

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Must match the branch order in `router.dart`.
const _destinations = [
  _Destination('Library', Icons.library_music_outlined, Icons.library_music),
  _Destination('Search', Icons.search_outlined, Icons.search),
  _Destination('Playlists', Icons.queue_music_outlined, Icons.queue_music),
  _Destination('Settings', Icons.settings_outlined, Icons.settings),
];

/// App frame around every top-level screen: a navigation rail on wide
/// windows (desktop), a bottom navigation bar on narrow ones (mobile).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    // Tapping the current destination again returns to its root page.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _railBreakpoint;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
