import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../shared/widgets/album_list_tile.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../library_browse_body.dart';

/// Row used to measure the list view.
const _prototypeAlbum = AlbumSummary(
  key: AlbumKey('', ''),
  title: 'Title',
  artist: 'Artist',
  trackCount: 1,
  addedAt: 0,
);

/// Albums as rows. Every row has the height of a prototype row, so a long
/// list does not measure each one.
class AlbumListView extends StatelessWidget {
  const AlbumListView({
    super.key,
    required this.albums,
    required this.onTap,
    this.onQueueAction,
    this.showTotals = true,
  });

  final List<AlbumSummary> albums;
  final void Function(AlbumSummary album) onTap;

  /// Picked from the menu of a right click or long press; no menu without it.
  final void Function(AlbumSummary album, QueueAction action)? onQueueAction;

  /// False blanks the "N songs • M min" line of every row (see
  /// [AlbumListTile.showTotals]).
  final bool showTotals;

  @override
  Widget build(BuildContext context) {
    final onQueueAction = this.onQueueAction;
    return ListView.builder(
      padding: libraryListBottomPadding,
      prototypeItem: AlbumListTile(
        album: _prototypeAlbum,
        onTap: () {},
        showTotals: showTotals,
      ),
      itemCount: albums.length,
      itemBuilder: (context, i) => AlbumListTile(
        album: albums[i],
        showTotals: showTotals,
        onTap: () => onTap(albums[i]),
        onQueueAction: onQueueAction == null
            ? null
            : (action) => onQueueAction(albums[i], action),
      ),
    );
  }
}
