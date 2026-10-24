import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart';
import '../../shared/in_page_filter.dart';
import '../../shared/widgets/in_page_search_field.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import '../../shared/widgets/song_tile.dart';

/// The songs of an artist or genre page as rows. [onTap] gets the position in
/// [songs] (which may be a filtered list), [onQueueAction] the song itself.
class SliverBrowseSongs extends StatelessWidget {
  const SliverBrowseSongs({
    super.key,
    required this.songs,
    required this.onTap,
    required this.onQueueAction,
  });

  final List<BrowseTrack> songs;
  final ValueChanged<int> onTap;
  final void Function(BrowseTrack song, QueueAction action) onQueueAction;

  @override
  Widget build(BuildContext context) => SliverList.builder(
    itemCount: songs.length,
    itemBuilder: (context, i) {
      final song = songs[i];
      return SongTile(
        song: TrackListItem(
          id: song.id,
          path: song.path,
          title: song.title,
          artist: song.artist,
          album: song.album,
          year: song.year,
          durationMs: song.durationMs,
          coverKey: song.coverKey,
        ),
        onTap: () => onTap(i),
        onQueueAction: (action) => onQueueAction(song, action),
      );
    },
  );
}

/// The "Songs" heading of an artist or genre page, with the filter button at
/// its end.
class SliverSongsHeading extends StatelessWidget {
  const SliverSongsHeading({
    super.key,
    required this.title,
    required this.filter,
  });

  final String title;
  final InPageFilterController filter;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          InPageSearchField(controller: filter),
        ],
      ),
    ),
  );
}
