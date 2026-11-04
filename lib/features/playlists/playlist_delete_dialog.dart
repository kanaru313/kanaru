import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/confirm_dialog.dart';

/// Asks whether to delete [playlist]; true only when confirmed. Cancel, Esc
/// and a tap outside all answer false.
Future<bool> confirmDeletePlaylist(
  BuildContext context,
  PlaylistSummary playlist,
) {
  final l10n = context.l10n;
  return confirmAction(
    context,
    title: l10n.playlistDeleteTitle(playlist.name),
    body: l10n.playlistDeleteBody(playlist.entryCount),
    confirmLabel: l10n.playlistDeleteConfirm,
  );
}

/// Asks whether to clear all songs from Favorites; true only when confirmed.
/// Cancel, Esc and a tap outside all answer false.
Future<bool> confirmClearFavorites(
  BuildContext context,
  int count,
) {
  final l10n = context.l10n;
  return confirmAction(
    context,
    title: l10n.favoritesClearTitle,
    body: l10n.favoritesClearBody(count),
    confirmLabel: l10n.favoritesClearConfirm,
  );
}
