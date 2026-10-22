import 'package:material_ui/material_ui.dart';

import '../../../core/database/playlist_rows.dart';
import '../../../l10n/l10n.dart';
import '../../icons/app_icons.dart';

/// The rows of the "add to playlist" picker: a "New playlist…" row, then
/// one row per playlist in the order given. The caller bounds its height.
class PlaylistPickerView extends StatelessWidget {
  const PlaylistPickerView({
    super.key,
    required this.playlists,
    required this.onCreate,
    required this.onPick,
  });

  final List<PlaylistSummary> playlists;
  final VoidCallback onCreate;
  final ValueChanged<PlaylistSummary> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      children: [
        ListTile(
          leading: const Icon(AppIcons.add),
          title: Text(l10n.playlistPickerNew),
          onTap: onCreate,
        ),
        if (playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.sidebarNoPlaylists,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final playlist in playlists)
          ListTile(
            leading: const Icon(AppIcons.queue),
            title: Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(l10n.playlistTrackCount(playlist.entryCount)),
            onTap: () => onPick(playlist),
          ),
      ],
    );
  }
}
