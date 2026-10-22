import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/playlist_providers.dart';
import '../../../core/database/playlist_rows.dart';
import '../../../l10n/l10n.dart';
import 'playlist_picker_view.dart';

/// What the user chose in the "add to playlist" picker.
sealed class PlaylistPick {
  const PlaylistPick();
}

/// An existing playlist.
final class PickedPlaylist extends PlaylistPick {
  const PickedPlaylist(this.playlist);

  final PlaylistSummary playlist;
}

/// "New playlist…": the caller asks for a name and creates it.
final class PickedNewPlaylist extends PlaylistPick {
  const PickedNewPlaylist();
}

/// The playlist picker over [context]'s navigator, listing the playlists
/// live (newest first). Completes with the choice, or null when dismissed.
Future<PlaylistPick?> showAddToPlaylistDialog(BuildContext context) =>
    showDialog<PlaylistPick>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.playlistPickerTitle),
        content: SizedBox(
          width: 360,
          height: 360,
          child: Consumer(
            builder: (context, ref, _) => ref
                .watch(playlistSummariesProvider)
                .when(
                  data: (playlists) => PlaylistPickerView(
                    playlists: playlists,
                    onCreate: () =>
                        Navigator.of(context).pop(const PickedNewPlaylist()),
                    onPick: (playlist) =>
                        Navigator.of(context).pop(PickedPlaylist(playlist)),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) =>
                      Center(child: Text(context.l10n.libraryUnexpectedError)),
                ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
        ],
      ),
    );
