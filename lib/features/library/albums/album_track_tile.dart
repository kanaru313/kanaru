import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../../../shared/widgets/song_tile.dart';

/// One track of an album page: the Songs list row ([SongTile]), with the
/// track number in a column before the cover unless track numbers are turned
/// off in Settings. The menu has no Show album: the page is the album.
class AlbumTrackTile extends ConsumerWidget {
  const AlbumTrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.onQueueAction,
  });

  final BrowseTrack track;
  final VoidCallback onTap;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numbers = ref.watch(
      settingsProvider.select((s) => s.display.trackNumbersInAlbum),
    );
    return SongTile(
      song: TrackListItem(
        id: track.id,
        path: track.path,
        title: track.title,
        artist: track.artist,
        album: track.album,
        year: track.year,
        durationMs: track.durationMs,
        coverKey: track.coverKey,
      ),
      number: numbers ? track.trackNo?.toString() ?? '' : null,
      showAlbum: false,
      onTap: onTap,
      onQueueAction: onQueueAction,
    );
  }
}
