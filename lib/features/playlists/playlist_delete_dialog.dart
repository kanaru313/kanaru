import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';

/// Asks whether to delete [playlist]; true only when confirmed. Cancel, Esc
/// and a tap outside all answer false.
Future<bool> confirmDeletePlaylist(
  BuildContext context,
  PlaylistSummary playlist,
) async {
  final l10n = context.l10n;
  final colors = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.playlistDeleteTitle(playlist.name)),
      content: Text(l10n.playlistDeleteBody(playlist.entryCount)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.playlistDeleteConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
