import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../shared/widgets/detail_page/collage_hero_cover.dart';
import '../../shared/widgets/detail_page/detail_side_pane.dart';
import 'playlist_details.dart';

/// Left column of a playlist page in a wide window: a hero card (the cover
/// collage washed out across the pane, with a smaller card of the same
/// collage over it), then the name, count and buttons at its right end (see
/// [DetailSidePane]).
class PlaylistSidePane extends StatelessWidget {
  const PlaylistSidePane({
    super.key,
    required this.head,
    required this.count,
    this.onPlay,
    this.onShuffle,
    this.savedQueue = false,
    this.beforeRead,
  });

  final PlaylistPageHead head;

  /// Entries in the list now (see `PlaylistHeader.count`).
  final int count;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;

  /// See `PlaylistDetails.savedQueue` and `PlaylistDetails.beforeRead`.
  final bool savedQueue;
  final Future<void> Function()? beforeRead;

  @override
  Widget build(BuildContext context) {
    final seed = 'playlist:${head.playlist.id}';
    return DetailSidePane(
      cover: CollageHeroBackdrop(coverKeys: head.coverKeys, seed: seed),
      coverOverlay: CollageHeroCard(coverKeys: head.coverKeys, seed: seed),
      details: PlaylistDetails(
        head: head,
        count: count,
        titleStyle: Theme.of(context).textTheme.headlineSmall,
        actionsAtEnd: true,
        onPlay: onPlay,
        onShuffle: onShuffle,
        savedQueue: savedQueue,
        beforeRead: beforeRead,
      ),
    );
  }
}
