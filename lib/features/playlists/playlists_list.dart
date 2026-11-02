import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import 'collage_list_row.dart';
import 'playlist_modal/open_playlist_modal.dart';
import 'playlist_modal/playlist_more_button.dart';

/// Every playlist as a row: collage, name and count. Tapping opens it.
class PlaylistsList extends ConsumerWidget {
  const PlaylistsList({super.key, required this.cards, required this.onOpen});

  final List<PlaylistCard> cards;
  final ValueChanged<PlaylistSummary> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemExtent: collageListRowExtent,
      itemCount: cards.length,
      itemBuilder: (context, i) {
        final card = cards[i];
        final playlist = card.playlist;
        return CollageListRow<void>(
          key: ValueKey(playlist.id),
          coverKeys: card.coverKeys,
          seed: 'playlist:${playlist.id}',
          title: playlist.name,
          subtitle: l10n.playlistTrackCount(playlist.entryCount),
          onTap: () => onOpen(playlist),
          trailing: PlaylistMoreButton(
            playlist: playlist,
            coverKeys: card.coverKeys,
          ),
          onOpenModal: ({required bool viaKeyboard}) => openPlaylistModal(
            context,
            ref,
            playlist: playlist,
            coverKeys: card.coverKeys,
            viaKeyboard: viaKeyboard,
          ),
        );
      },
    );
  }
}
