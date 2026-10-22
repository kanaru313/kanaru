import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/database/playlist_providers.dart';
import '../../../features/playlists/playlist_routes.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/add_to_playlist/create_playlist_prompt.dart';
import '../navigation_history.dart';
import 'sidebar_item.dart';
import 'sidebar_playlists_rail.dart';

/// Collapsible "Playlists" group at the bottom of the sidebar: the playlists
/// newest first, the one on screen highlighted, and a button that asks for a
/// name, creates a playlist and opens it. The title opens the playlists page.
/// In [compact] mode (the collapsed rail) only a button and one entry for
/// the page are shown.
class SidebarPlaylistsSection extends ConsumerStatefulWidget {
  const SidebarPlaylistsSection({
    super.key,
    this.compact = false,
    required this.playlistsSelected,
    required this.onOpenPlaylists,
    required this.onOpenLocation,
  });

  final bool compact;

  /// Whether the playlists branch is the current page (the rail's entry).
  final bool playlistsSelected;

  /// Switches to the playlists branch like any other destination: back to
  /// its last page, or to its root when it is already current.
  final VoidCallback onOpenPlaylists;

  /// Opens a location such as `/playlists/3`; the drawer closes itself first.
  final ValueChanged<String> onOpenLocation;

  @override
  ConsumerState<SidebarPlaylistsSection> createState() =>
      _SidebarPlaylistsSectionState();
}

class _SidebarPlaylistsSectionState
    extends ConsumerState<SidebarPlaylistsSection> {
  bool _expanded = true;

  Future<void> _create() async {
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    final created = await promptAndCreatePlaylist(
      context,
      db,
      ScaffoldMessenger.of(context),
      context.l10n,
    );
    if (created != null && mounted) {
      widget.onOpenLocation(playlistLocation(created.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(libraryDatabaseProvider) != null;
    final onCreate = canCreate ? _create : null;
    if (widget.compact) {
      return SidebarPlaylistsRail(
        selected: widget.playlistsSelected,
        onCreate: onCreate,
        onOpen: widget.onOpenPlaylists,
      );
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final playlists = ref.watch(playlistSummariesProvider).value ?? const [];
    // Only the path: a query string must not hide the highlight.
    final currentId = playlistIdOfLocation(
      Uri.parse(
        ref.watch(navigationHistoryProvider.select((h) => h.entries[h.index])),
      ).path,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    button: true,
                    selected: widget.playlistsSelected,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: widget.onOpenPlaylists,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          l10n.sidebarPlaylists,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: widget.playlistsSelected
                                ? theme.colorScheme.primary
                                : muted,
                            fontWeight: widget.playlistsSelected
                                ? FontWeight.bold
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(AppIcons.add, size: 18),
                tooltip: l10n.sidebarNewPlaylist,
                visualDensity: VisualDensity.compact,
                onPressed: onCreate,
              ),
              IconButton(
                icon: Icon(
                  _expanded ? AppIcons.expandLess : AppIcons.expandMore,
                  size: 18,
                ),
                tooltip: _expanded ? l10n.sidebarCollapse : l10n.sidebarExpand,
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ],
          ),
        ),
        if (_expanded && playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              l10n.sidebarNoPlaylists,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        if (_expanded)
          for (final playlist in playlists)
            SidebarItem(
              key: ValueKey(playlist.id),
              icon: AppIcons.queueOutlined,
              selectedIcon: AppIcons.queue,
              label: playlist.name,
              selected: currentId == playlist.id,
              onTap: () => widget.onOpenLocation(playlistLocation(playlist.id)),
            ),
      ],
    );
  }
}

/// The playlist id of a page location such as `/playlists/3`, else null.
/// Parsed, so `/playlists/05` still marks playlist 5.
@visibleForTesting
int? playlistIdOfLocation(String path) {
  final segments = Uri.parse(path).pathSegments;
  if (segments.length != 2 || '/${segments.first}' != playlistsPath) {
    return null;
  }
  return parsePlaylistRouteId(segments.last);
}
