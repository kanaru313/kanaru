import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/album_artist_label.dart';
import '../../../shared/widgets/album_artwork.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../../../shared/widgets/detail_page/play_shuffle_actions.dart';

/// Header of an album page in a narrow window: artwork beside the title,
/// artist, year and the Play buttons. The song count and length sit in the
/// bar over the tracks. A wide window shows `AlbumSidePane` instead.
class AlbumHeader extends StatelessWidget {
  const AlbumHeader({
    super.key,
    required this.albumKey,
    required this.album,
    required this.onPlay,
    required this.onShuffle,
    required this.onQueueAction,
    this.artist,
  });

  final AlbumKey albumKey;
  final AlbumSummary album;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final ValueChanged<QueueAction> onQueueAction;

  /// Replaces the plain artist name, for example with a link.
  final Widget? artist;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AlbumArtwork(albumKey: albumKey, coverKey: album.coverKey, size: 160),
          const SizedBox(width: 24),
          Expanded(
            child: AlbumHeaderDetails(
              album: album,
              artist: artist,
              titleStyle: Theme.of(context).textTheme.headlineMedium,
              onPlay: onPlay,
              onShuffle: onShuffle,
              onQueueAction: onQueueAction,
            ),
          ),
        ],
      ),
    );
  }
}

/// Title (bold, two lines at most), artist, year and the Play buttons of an
/// album, shared by [AlbumHeader] and the wide window's side pane.
class AlbumHeaderDetails extends StatelessWidget {
  const AlbumHeaderDetails({
    super.key,
    required this.album,
    required this.titleStyle,
    required this.onPlay,
    required this.onShuffle,
    required this.onQueueAction,
    this.artist,
    this.actionsAtEnd = false,
  });

  final AlbumSummary album;
  final TextStyle? titleStyle;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final ValueChanged<QueueAction> onQueueAction;

  /// Puts the Play buttons at the right end of the column, as in the side pane.
  final bool actionsAtEnd;

  /// Replaces the plain artist name, for example with a link.
  final Widget? artist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final year = album.year;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          album.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        artist ??
            Text(
              albumArtistLabel(
                l10n,
                artist: album.artist,
                variousArtists: album.variousArtists,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
        if (year != null && year > 0) ...[
          const SizedBox(height: 4),
          Text(
            '$year',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: actionsAtEnd
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: PlayShuffleActions(
            playLabel: l10n.albumsPlay,
            onPlay: onPlay,
            onShuffle: onShuffle,
            onQueueAction: onQueueAction,
          ),
        ),
      ],
    );
  }
}
