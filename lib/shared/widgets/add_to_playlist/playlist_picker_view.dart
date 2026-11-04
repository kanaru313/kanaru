import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/playlist_rows.dart';
import '../../../l10n/l10n.dart';
import '../../icons/app_icons.dart';

/// A playlist the user named in the picker; created only when Add is pressed.
typedef PendingPlaylist = ({String name, bool on});

/// The rows of the multi-select picker: a "New playlist…" row, the pending
/// new playlists (newest first), then one checkbox row per playlist in the
/// order given. The caller bounds its height.
///
/// Tapping a row only toggles it. Enter on a playlist row presses Add through
/// [onSubmit] (a row binding, so a focused button keeps its own Enter).
class PlaylistPickerView extends StatelessWidget {
  const PlaylistPickerView({
    super.key,
    required this.playlists,
    required this.ticked,
    required this.pending,
    required this.overlaps,
    required this.onCreate,
    required this.onToggle,
    required this.onTogglePending,
    required this.onSubmit,
    this.enabled = true,
    this.pendingFocus,
    this.autofocusNew = false,
  });

  final List<PlaylistSummary> playlists;
  final Set<int> ticked;
  final List<PendingPlaylist> pending;

  /// Playlist id to how many of the songs it already holds.
  final Map<int, int> overlaps;
  final VoidCallback onCreate;
  final ValueChanged<PlaylistSummary> onToggle;
  final ValueChanged<int> onTogglePending;
  final VoidCallback onSubmit;

  /// False while Add runs: every row is inert.
  final bool enabled;

  /// Focus node of the newest pending row.
  final FocusNode? pendingFocus;

  /// True when the "New playlist…" row takes focus on mount (opened from
  /// the keyboard, or with a screen reader on).
  final bool autofocusNew;

  Widget _row({
    Key? key,
    required bool value,
    required IconData icon,
    required Widget title,
    required String subtitle,
    required VoidCallback onTap,
    FocusNode? focusNode,
  }) => CallbackShortcuts(
    key: key,
    bindings: {
      const SingleActivator(LogicalKeyboardKey.enter): onSubmit,
      const SingleActivator(LogicalKeyboardKey.numpadEnter): onSubmit,
    },
    child: CheckboxListTile(
      focusNode: focusNode,
      value: value,
      onChanged: enabled ? (_) => onTap() : null,
      controlAffinity: ListTileControlAffinity.leading,
      secondary: Icon(icon),
      title: title,
      subtitle: Text(subtitle),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      children: [
        ListTile(
          autofocus: autofocusNew,
          enabled: enabled,
          leading: const Icon(AppIcons.add),
          title: Text(l10n.playlistPickerNew),
          onTap: onCreate,
        ),
        for (final (i, item) in pending.indexed)
          _row(
            key: ValueKey('pending-$i'),
            value: item.on,
            icon: AppIcons.playlist,
            focusNode: i == 0 ? pendingFocus : null,
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  label: Text(l10n.playlistPickerNewBadge),
                  backgroundColor: theme.colorScheme.primaryContainer,
                  textColor: theme.colorScheme.onPrimaryContainer,
                ),
              ],
            ),
            subtitle: l10n.playlistPickerNewHint,
            onTap: () => onTogglePending(i),
          ),
        if (playlists.isEmpty && pending.isEmpty)
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
          _row(
            key: ValueKey(playlist.id),
            value: ticked.contains(playlist.id),
            icon: AppIcons.playlist,
            title: Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: [
              l10n.playlistTrackCount(playlist.entryCount),
              if ((overlaps[playlist.id] ?? 0) > 0)
                l10n.playlistPickerHasSome(overlaps[playlist.id]!),
            ].join(' · '),
            onTap: () => onToggle(playlist),
          ),
      ],
    );
  }
}
