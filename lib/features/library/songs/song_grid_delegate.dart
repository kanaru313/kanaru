import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/library_grid/song_grid_tile.dart';
import '../albums/album_grid.dart' show libraryGridDelegate;

/// Grid layout of the Songs grid in a [width] wide area.
SliverGridDelegate songGridDelegate(BuildContext context, double width) =>
    libraryGridDelegate(context, width, tileHeight: SongGridTile.heightFor);
