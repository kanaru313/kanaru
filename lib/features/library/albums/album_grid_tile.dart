import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../l10n/l10n.dart';
import '../library_browse_body.dart';
import '../../../shared/widgets/album_artwork.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import 'album_tile_data.dart';

/// Padding around the content of a grid tile and the gap between the picture
/// and the text; shared by the round tiles, whose height is derived from here.
const gridTilePadding = 8.0;
const gridTileGap = 8.0;

/// One album in a grid: square artwork, title, "artist · year".
class AlbumGridTile extends StatelessWidget {
  const AlbumGridTile({
    super.key,
    required this.data,
    required this.onTap,
    this.onQueueAction,
  });

  final AlbumTileData data;
  final VoidCallback onTap;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  /// Height of a tile [width] wide: the square artwork plus two text lines
  /// at the current text scale, so large text never overflows.
  static double heightFor(BuildContext context, double width) {
    final theme = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle? style) {
      final size = style?.fontSize ?? 14;
      return scaler.scale(size) * (style?.height ?? 1.2);
    }

    return width +
        gridTileGap +
        line(theme.titleSmall) +
        line(theme.bodySmall) +
        // Rounding slack so a fractional line height never clips.
        2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final subtitle = [
      data.artist ?? l10n.albumsUnknownArtist,
      if (data.year != null) '${data.year}',
    ].join(' · ');

    final tile = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(gridTilePadding),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AlbumArtwork(
                albumKey: data.key,
                coverKey: data.coverKey,
                size: constraints.maxWidth,
              ),
              const SizedBox(height: gridTileGap),
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return QueueActionsRegion(onAction: onQueueAction, child: tile);
  }
}

/// Side padding of album grids.
const albumGridPadding = 24.0;

const _maxTileWidth = 200.0;

/// Columns of tiles at most 200 px wide filling [width]; [tileHeight] gives
/// the height of a tile from the width of its content (the tile minus its
/// padding), so rows fit the artwork and the text at the current text scale.
SliverGridDelegate libraryGridDelegate(
  BuildContext context,
  double width, {
  required double Function(BuildContext context, double contentWidth)
  tileHeight,
}) {
  final columns = (width / _maxTileWidth).ceil().clamp(1, 1 << 20);
  final tileWidth = width / columns;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    mainAxisExtent:
        tileHeight(context, tileWidth - gridTilePadding * 2) +
        gridTilePadding * 2,
  );
}

/// [libraryGridDelegate] for album tiles: artwork and two lines of text.
SliverGridDelegate albumGridDelegate(BuildContext context, double width) =>
    libraryGridDelegate(context, width, tileHeight: AlbumGridTile.heightFor);

/// [albums] as a scrolling grid, leaving room for the rescan button below.
/// Tile data is made per visible tile, not for the whole list.
class AlbumGrid extends StatelessWidget {
  const AlbumGrid({
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          albumGridPadding,
          0,
          albumGridPadding,
          libraryBottomInset,
        ),
        gridDelegate: albumGridDelegate(
          context,
          constraints.maxWidth - albumGridPadding * 2,
        ),
        itemCount: albums.length,
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
}

/// [albums] as a grid inside a [CustomScrollView].
class SliverAlbumGrid extends StatelessWidget {
  const SliverAlbumGrid({
    super.key,
    required this.albums,
    required this.onTap,
    this.onQueueAction,
  });

  final List<AlbumTileData> albums;
  final void Function(AlbumTileData album) onTap;

  /// An action picked from the menu of [album]; no menus without it.
  final void Function(AlbumTileData album, QueueAction action)? onQueueAction;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: albumGridPadding),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) => SliverGrid.builder(
          gridDelegate: albumGridDelegate(context, constraints.crossAxisExtent),
          itemCount: albums.length,
          itemBuilder: (context, i) => AlbumGridTile(
            data: albums[i],
            onTap: () => onTap(albums[i]),
            onQueueAction: onQueueAction == null
                ? null
                : (action) => onQueueAction!(albums[i], action),
          ),
        ),
      ),
    );
  }
}
