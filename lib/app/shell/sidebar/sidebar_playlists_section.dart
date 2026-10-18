import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';

/// Collapsible "Playlists" group at the bottom of the sidebar. Lists nothing
/// until playlists exist; the add button stays disabled until then. In
/// [compact] mode (the collapsed rail) only the add button is shown.
class SidebarPlaylistsSection extends StatefulWidget {
  const SidebarPlaylistsSection({super.key, this.compact = false});

  final bool compact;

  @override
  State<SidebarPlaylistsSection> createState() =>
      _SidebarPlaylistsSectionState();
}

class _SidebarPlaylistsSectionState extends State<SidebarPlaylistsSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    if (widget.compact) {
      return Center(
        child: IconButton(
          icon: const Icon(Icons.playlist_add, size: 22),
          tooltip: l10n.sidebarNewPlaylist,
          onPressed: null,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.sidebarPlaylists,
                  style: theme.textTheme.labelMedium?.copyWith(color: muted),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: l10n.sidebarNewPlaylist,
                visualDensity: VisualDensity.compact,
                onPressed: null,
              ),
              IconButton(
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                tooltip: _expanded ? l10n.sidebarCollapse : l10n.sidebarExpand,
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ],
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              l10n.sidebarNoPlaylists,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
      ],
    );
  }
}
