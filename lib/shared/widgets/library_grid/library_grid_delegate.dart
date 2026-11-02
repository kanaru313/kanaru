import 'package:material_ui/material_ui.dart';

import 'library_grid_card.dart';

const _maxTileWidth = 200.0;

/// Side padding of the library grids (albums, artists, genres, languages,
/// folders, songs).
const libraryGridPadding = 24.0;

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
