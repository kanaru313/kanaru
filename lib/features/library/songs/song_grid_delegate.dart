import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/library_grid/song_grid_tile.dart';
import '../../../shared/widgets/library_grid/library_grid_delegate.dart';

/// Grid layout of the Songs grid in a [width] wide area.
SliverGridDelegate songGridDelegate(BuildContext context, double width) =>
    libraryGridDelegate(context, width, tileHeight: SongGridTile.heightFor);
