import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../shared/widgets/album_artwork.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import 'album_header.dart';

/// Width of the side pane of an album page in a wide window.
const albumSidePaneWidth = 320.0;

/// Narrowest page that gets the side pane: the pane plus room for a track
/// list that still shows title, artist and length.
const albumSidePaneMinPageWidth = 840.0;

/// Left column of an album page in a wide window: the cover the width of the
/// pane, fading into the page at its foot, then the title, artist, year and
/// the Play buttons. It stays put while the tracks beside it scroll, and
/// scrolls on its own when the window is too short for it.
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
    return SizedBox(
      width: albumSidePaneWidth,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.7, 1],
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0x00FFFFFF),
                ],
              ).createShader(bounds),
              child: AlbumArtwork(
                albumKey: albumKey,
                coverKey: album.coverKey,
                size: albumSidePaneWidth,
                radius: 0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: AlbumHeaderDetails(
                album: album,
                artist: artist,
                titleStyle: Theme.of(context).textTheme.headlineSmall,
                onPlay: onPlay,
                onShuffle: onShuffle,
                onQueueAction: onQueueAction,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
