import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart';
import '../../shared/song_modal/song_modal_extras.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import '../../shared/widgets/song_tile.dart';

/// The songs of an artist or genre page as rows. [onTap] gets the position in
/// [songs] (which may be a filtered list), [onQueueAction] the song itself.
/// On an artist page, [pageArtistKey] is that artist: the song modal's artist
/// links leave it out.
class SliverBrowseSongs extends StatelessWidget {
  const SliverBrowseSongs({
    super.key,
    required this.songs,
    required this.onTap,
    required this.onQueueAction,
    this.pageArtistKey,
  });

  final List<BrowseTrack> songs;
  final ValueChanged<int> onTap;
  final void Function(BrowseTrack song, QueueAction action) onQueueAction;
  final String? pageArtistKey;

  @override
  Widget build(BuildContext context) {
    final page = pageArtistKey;
    return SliverList.builder(
      itemCount: songs.length,
      itemBuilder: (context, i) {
        final song = songs[i];
        return SongTile(
          song: song,
          onTap: () => onTap(i),
          onQueueAction: (action) => onQueueAction(song, action),
          modalExtras: page == null
              ? null
              : () => SongModalExtras(pageArtistKey: page),
        );
      },
    );
  }
}
