import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../shared/widgets/card_shelf.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../../../shared/widgets/library_grid/album_grid_tile.dart';
import '../../../shared/widgets/library_grid/album_tile_data.dart';
import '../../../shared/widgets/library_grid/library_grid_card.dart';

/// Width of the artwork of a tile in an [SliverAlbumRow].
const _artworkWidth = 160.0;

/// Space between a cell's edge and the artwork: the card's margin and padding.
const _cellInset = libraryGridCardMargin + libraryGridCardPadding;

/// [albums] as one line of grid tiles inside a [CustomScrollView], scrolling
/// sideways like the Home shelves ([CardShelf]): arrow buttons, mouse drag,
/// trackpad and Shift+wheel. The tile data is made per built tile, so a long
/// row costs only what is on screen.
class SliverAlbumRow extends StatelessWidget {
  const SliverAlbumRow({
    super.key,
    required this.albums,
    required this.onTap,
    this.onQueueAction,
  });

  final List<AlbumSummary> albums;
  final void Function(AlbumSummary album) onTap;

  /// An action picked from the menu of [album]; no menus without it.
  final void Function(AlbumSummary album, QueueAction action)? onQueueAction;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: CardShelf(
      itemCount: albums.length,
      itemExtent: _artworkWidth + _cellInset * 2,
      height: AlbumGridTile.heightFor(context, _artworkWidth) + _cellInset * 2,
      // The arrows center on the artwork, not on the text below it.
      arrowTop: _cellInset + _artworkWidth / 2 - 24,
      itemBuilder: (context, i) => AlbumGridTile(
        data: AlbumTileData.fromSummary(albums[i]),
        onTap: () => onTap(albums[i]),
        onQueueAction: onQueueAction == null
            ? null
            : (action) => onQueueAction!(albums[i], action),
      ),
    ),
  );
}
