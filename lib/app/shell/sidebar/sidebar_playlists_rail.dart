import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../app_destination.dart';
import 'sidebar_item.dart';
import 'sidebar_tooltip.dart';

/// The playlists section on the collapsed rail: a button to create a
/// playlist ([onCreate] null disables it) and one entry for the playlists
/// page.
class SidebarPlaylistsRail extends StatelessWidget {
  const SidebarPlaylistsRail({
    super.key,
    required this.selected,
    required this.onCreate,
    required this.onOpen,
  });

  final bool selected;
  final VoidCallback? onCreate;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SidebarTooltip(
            message: l10n.sidebarNewPlaylist,
            child: IconButton(
              icon: const Icon(Icons.playlist_add, size: 22),
              onPressed: onCreate,
            ),
          ),
        ),
        SidebarItem(
          icon: AppDestination.playlists.icon,
          selectedIcon: AppDestination.playlists.selectedIcon,
          label: l10n.sidebarPlaylists,
          selected: selected,
          compact: true,
          onTap: onOpen,
        ),
      ],
    );
  }
}
