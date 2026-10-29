import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart';
import '../../l10n/l10n.dart';
import '../album_artist_label.dart';
import '../enqueue_tracks.dart';
import 'album_artwork.dart';
import 'library_row.dart';
import 'queue_actions_menu.dart';

/// One album row: artwork, then three lines (title, "artist • year",
/// "N songs • M min"), then a play button shown while the row is hovered or
/// focused, which plays the whole album. Every line is always laid out, so
/// all rows have the height of the list's prototype row.
class AlbumListTile extends ConsumerWidget {
  const AlbumListTile({
    super.key,
    required this.album,
    required this.onTap,
    this.onQueueAction,
    this.showTotals = true,
  });

  final AlbumSummary album;
  final VoidCallback onTap;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  /// False leaves the "N songs • M min" line blank, for lists whose albums
  /// hold more songs than the list is about; the row keeps its height.
  final bool showTotals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final durationMs = album.durationMs;
    final tile = LibraryPlayableRow(
      leading: AlbumArtwork(
        albumKey: album.key,
        coverKey: album.coverKey,
        size: libraryRowCoverSize,
      ),
      lines: [
        album.title,
        joinRowDetails([
          albumArtistLabel(
            l10n,
            artist: album.artist,
            variousArtists: album.variousArtists,
          ),
          rowYear(album.year),
        ]),
        if (showTotals)
          joinRowDetails([
            l10n.albumsSongCount(album.trackCount),
            if (durationMs != null) l10n.albumsMinutes(rowMinutes(durationMs)),
          ])
        else
          '',
      ],
      onTap: onTap,
      onPlay: () => unawaited(playAlbum(ref, album.key)),
      playTooltip: l10n.albumsPlayAlbum,
    );
    return QueueActionsRegion(onAction: onQueueAction, child: tile);
  }
}
