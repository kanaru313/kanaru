import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../shared/song_modal/song_modal_extras.dart';
import '../../../shared/widgets/in_page_no_match.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../../../shared/widgets/song_tile.dart';

/// The number column of an album track row: the track number, blank when the
/// track has none; null (no column) when track numbers are turned off in
/// Settings ([numbers] false).
String? albumTrackNumber(BrowseTrack track, {required bool numbers}) =>
    numbers ? track.trackNo?.toString() ?? '' : null;

/// One track row on an album page, in the disc groups or the filtered list:
/// the number column follows [numbers] (see [albumTrackNumber]) and the song
/// modal has no Go to album (the page is the album).
class AlbumTrackRow extends StatelessWidget {
  const AlbumTrackRow({
    super.key,
    required this.track,
    required this.numbers,
    required this.onTap,
    required this.onQueueAction,
  });

  final BrowseTrack track;

  /// Track numbers in albums is on (Settings).
  final bool numbers;
  final VoidCallback onTap;
  final ValueChanged<QueueAction> onQueueAction;

  @override
  Widget build(BuildContext context) => SongTile(
    song: track,
    number: albumTrackNumber(track, numbers: numbers),
    onTap: onTap,
    onQueueAction: onQueueAction,
    modalExtras: () => const SongModalExtras(showAlbum: false),
  );
}

/// The tracks of an album that match the filter, best match first as one flat
/// list (no disc groups). [onTap] gets the position in [tracks]. Rows are
/// [AlbumTrackRow]s, the same as in the disc groups.
class SliverAlbumFilteredTracks extends StatelessWidget {
  const SliverAlbumFilteredTracks({
    super.key,
    required this.tracks,
    required this.numbers,
    required this.query,
    required this.onTap,
    required this.onQueueAction,
  });

  final List<BrowseTrack> tracks;

  /// Track numbers in albums is on (Settings).
  final bool numbers;

  /// What was typed, for the message when nothing matches.
  final String query;
  final ValueChanged<int> onTap;
  final void Function(BrowseTrack track, QueueAction action) onQueueAction;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return SliverToBoxAdapter(child: InPageNoMatch(query: query));
    }
    return SliverList.builder(
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        final track = tracks[i];
        return AlbumTrackRow(
          track: track,
          numbers: numbers,
          onTap: () => onTap(i),
          onQueueAction: (action) => onQueueAction(track, action),
        );
      },
    );
  }
}
