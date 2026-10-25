import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../shared/widgets/album_artwork.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../widgets/detail_side_pane.dart';
import 'album_header.dart';

/// Left column of an album page in a wide window: the album cover, then
/// the title, artist, year and the Play buttons at its right end (see
/// [DetailSidePane]).
class AlbumSidePane extends StatelessWidget {
  const AlbumSidePane({
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
    return DetailSidePane(
      cover: AlbumArtwork(
        albumKey: albumKey,
        coverKey: album.coverKey,
        size: detailSidePaneWidth,
        radius: 0,
      ),
      details: AlbumHeaderDetails(
        album: album,
        artist: artist,
        actionsAtEnd: true,
        titleStyle: Theme.of(context).textTheme.headlineSmall,
        onPlay: onPlay,
        onShuffle: onShuffle,
        onQueueAction: onQueueAction,
      ),
    );
  }
}
