import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../artist_summaries.dart';
import 'artist_avatar.dart';
import 'library_row.dart';
import 'queue_actions_menu.dart';

/// "2012 – 2024", one year when both ends are the same, or null when no
/// track of the artist has a year.
String? _yearSpan(int? first, int? last) {
  final from = rowYear(first);
  final to = rowYear(last);
  if (from == null || to == null) return from ?? to;
  return from == to ? from : '$from – $to';
}

/// One artist row: avatar, then three lines (name, "N albums • M songs",
/// "first year – last year • total length"), then a play button shown while
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
        joinRowDetails([
          l10n.artistsAlbumCount(artist.albumCount),
          l10n.albumsSongCount(artist.songCount),
        ]),
        joinRowDetails([
          _yearSpan(artist.firstYear, artist.lastYear),
          if (durationMs != null) rowLength(l10n, durationMs),
        ]),
      ],
      onTap: onTap,
      onPlay: onPlay,
      playTooltip: l10n.artistsPlayArtist,
    );
    return QueueActionsRegion(onAction: onQueueAction, child: tile);
  }
}
