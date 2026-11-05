import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/library_row.dart';
import '../../shared/widgets/playlist_cover.dart';
import '../../shared/widgets/song_card.dart';
import 'playlist_display_name.dart';
import 'playlist_modal/playlist_actions_region.dart';
import 'playlist_modal/playlist_more_button.dart';
import 'playlist_play_actions.dart';

/// Every playlist as a row: collage, name, count, and duration. Tapping opens it.
class PlaylistsList extends ConsumerWidget {
  const PlaylistsList({super.key, required this.cards, required this.onOpen});

  final List<PlaylistCard> cards;
  final ValueChanged<PlaylistSummary> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemExtent: songCardExtent(theme, scaler),
      itemCount: cards.length,
      itemBuilder: (context, i) {
        final card = cards[i];
        final playlist = card.playlist;
        final durationMs = playlist.durationMs;
        return PlaylistActionsRegion(
          key: ValueKey(playlist.id),
          playlist: playlist,
          coverKeys: card.coverKeys,
          child: SongCardFrame(
            child: LibraryPlayableRow(
              leading: PlaylistCover(
                coverKeys: card.coverKeys,
                size: libraryRowCoverSize,
                seed: 'playlist:${playlist.id}',
              ),
              lines: [
                playlistDisplayName(playlist, l10n),
                joinRowDetails([
                  l10n.playlistTrackCount(playlist.entryCount),
                  if (durationMs != null && durationMs > 0)
                    rowLength(l10n, durationMs),
                ]),
                playlist.description.isNotEmpty
                    ? playlist.description
                    : l10n.playlistCreatedOn(
                        DateTime.fromMillisecondsSinceEpoch(playlist.createdAt),
                      ),
              ],
              onTap: () => onOpen(playlist),
              onPlay: playlist.entryCount > 0
                  ? () => unawaited(
                      playPlaylistFrom(
                        ref,
                        context,
                        () => true,
                        playlist.id,
                        null,
                        0,
                      ),
                    )
                  : null,
              playTooltip: l10n.albumsPlay,
              more: PlaylistMoreButton(
                playlist: playlist,
                coverKeys: card.coverKeys,
              ),
              horizontalPadding: songCardInset,
              inkBorder: songCardShape,
            ),
          ),
        );
      },
    );
  }
}
