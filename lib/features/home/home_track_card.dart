import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart' show TrackListItem;
import '../../core/database/library_startup.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/library_grid/song_grid_tile.dart';

/// One song on a shelf, drawn as the Songs grid card. Tapping plays the whole
/// [row] from this song; the menu queues just this song.
class HomeTrackCard extends ConsumerWidget {
  const HomeTrackCard({super.key, required this.row, required this.index});

  /// The songs on the shelf; the queue made by a tap.
  final List<TrackListItem> row;

  /// Position of this card's song in [row].
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = row[index];
    final covers = ref.watch(coverCacheDirectoryProvider);
    return SongGridTile(
      song: song,
      onTap: () => playTracks(ref, [
        for (final t in row) trackFromListItem(t, covers),
      ], index),
      onQueueAction: (action) => enqueueLoaded(ref, context, action, [
        trackFromListItem(song, covers),
      ], song.title),
    );
  }
}
