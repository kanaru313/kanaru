import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../artist_summaries.dart';
import 'artist_avatar.dart';
import 'library_row.dart';
import 'queue_actions_menu.dart';
import 'song_card.dart';

/// One artist row, drawn as a card like a song row: avatar, then three lines (name, "N albums",
/// "M songs • total length"), then a play button shown while
/// the row is hovered or focused; no button without [onPlay]. Every line is
/// always laid out, so all rows have the height of the list's prototype row.
class ArtistTile extends StatelessWidget {
  const ArtistTile({
    super.key,
    required this.artist,
    required this.onTap,
    this.onPlay,
    this.onQueueAction,
  });

  final ArtistSummary artist;
  final VoidCallback onTap;

  /// Plays every song of the artist; the caller picks the order.
  final VoidCallback? onPlay;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final durationMs = artist.durationMs;
    final tile = LibraryPlayableRow(
      leading: ArtistAvatar(
        artistKey: artist.key,
        name: artist.name,
        size: libraryRowCoverSize,
      ),
      lines: [
        artist.name,
        l10n.artistsAlbumCount(artist.albumCount),
        joinRowDetails([
          l10n.albumsSongCount(artist.songCount),
          if (durationMs != null) rowLength(l10n, durationMs),
        ]),
      ],
      onTap: onTap,
      onPlay: onPlay,
      playTooltip: l10n.artistsPlayArtist,
      // The card takes 16 px; with these 16 the content sits 32 px from the
      // list edge, like the text of a song row.
      horizontalPadding: songCardInset,
      inkBorder: songCardShape,
    );
    return QueueActionsRegion(
      onAction: onQueueAction,
      child: SongCardFrame(child: tile),
    );
  }
}
