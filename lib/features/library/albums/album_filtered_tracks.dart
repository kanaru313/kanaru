import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../shared/in_page_filter.dart';
import '../../../shared/widgets/in_page_no_match.dart';
import '../../../shared/widgets/in_page_search_field.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import 'album_track_tile.dart';

/// The row under the album header that holds the filter button.
class SliverAlbumFilterBar extends StatelessWidget {
  const SliverAlbumFilterBar({super.key, required this.filter});

  final InPageFilterController filter;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: InPageSearchField(controller: filter),
      ),
    ),
  );
}

/// The tracks of an album that match the filter, best match first as one flat
/// list (no disc groups). [onTap] gets the position in [tracks].
class SliverAlbumFilteredTracks extends StatelessWidget {
  const SliverAlbumFilteredTracks({
    super.key,
    required this.tracks,
    required this.query,
    required this.onTap,
    required this.onQueueAction,
  });

  final List<BrowseTrack> tracks;

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
      itemBuilder: (context, i) => AlbumTrackTile(
        track: tracks[i],
        onTap: () => onTap(i),
        onQueueAction: (action) => onQueueAction(tracks[i], action),
      ),
    );
  }
}
