import 'package:material_ui/material_ui.dart';

import '../albums/album_grid_tile.dart';
import '../widgets/round_grid_tile.dart';
import 'folder_grid_tile.dart';
import 'folder_menu.dart';
import 'folder_tree.dart';

/// A folder to show in [FolderGrid] or [SliverFolderGrid]: the node, the name
/// to show for it, and in flat mode the line of folders above it and whether
/// it stands for its own songs only.
typedef FolderEntry = ({
  FolderNode folder,
  String title,
  String? parentLine,
  bool direct,
});

/// Height of a [FolderGridTile] whose art is [width] wide: a round tile's, and
/// one more text line when [withParentLine].
double folderGridTileHeight(
  BuildContext context,
  double width, {
  bool withParentLine = false,
}) {
  // The line height as [roundGridTileHeight] computes it for its bodySmall line.
  final style = Theme.of(context).textTheme.bodySmall;
  final line =
      MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 14) *
      (style?.height ?? 1.2);
  return roundGridTileHeight(context, width) + (withParentLine ? line : 0);
}

bool _anyParentLine(List<FolderEntry> folders) =>
    folders.any((e) => e.parentLine != null);

Widget _tile(
  FolderEntry entry,
  void Function(FolderNode folder) onTap,
  void Function(FolderNode folder, FolderAction action)? onAction, {
  required bool showPaths,
}) => FolderGridTile(
  folder: entry.folder,
  title: entry.title,
  onTap: () => onTap(entry.folder),
  showPath: entry.folder.ambiguousRoot && showPaths,
  parentLine: entry.parentLine,
  direct: entry.direct,
  onAction: onAction == null
      ? null
      : (action) => onAction(entry.folder, action),
);

/// [folders] as a scrolling grid.
class FolderGrid extends StatelessWidget {
  const FolderGrid({
    super.key,
    required this.folders,
    required this.onTap,
    this.showPaths = false,
    this.onAction,
  });

  final List<FolderEntry> folders;
  final void Function(FolderNode folder) onTap;

  /// Whether folders in music folders that share a name show their path.
  final bool showPaths;
  final void Function(FolderNode folder, FolderAction action)? onAction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        albumGridPadding,
        0,
        albumGridPadding,
        24,
      ),
      gridDelegate: libraryGridDelegate(
        context,
        constraints.maxWidth - albumGridPadding * 2,
        tileHeight: (context, width) => folderGridTileHeight(
          context,
          width,
          withParentLine: _anyParentLine(folders),
        ),
      ),
      itemCount: folders.length,
      itemBuilder: (context, i) =>
          _tile(folders[i], onTap, onAction, showPaths: showPaths),
    ),
  );
}

/// [folders] as a grid inside a [CustomScrollView].
class SliverFolderGrid extends StatelessWidget {
  const SliverFolderGrid({
    super.key,
    required this.folders,
    required this.onTap,
    this.showPaths = false,
    this.onAction,
  });

  final List<FolderEntry> folders;
  final void Function(FolderNode folder) onTap;

  /// Whether folders in music folders that share a name show their path.
  final bool showPaths;
  final void Function(FolderNode folder, FolderAction action)? onAction;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: albumGridPadding),
    sliver: SliverLayoutBuilder(
      builder: (context, constraints) => SliverGrid.builder(
        gridDelegate: libraryGridDelegate(
          context,
          constraints.crossAxisExtent,
          tileHeight: (context, width) => folderGridTileHeight(
            context,
            width,
            withParentLine: _anyParentLine(folders),
          ),
        ),
        itemCount: folders.length,
        itemBuilder: (context, i) =>
            _tile(folders[i], onTap, onAction, showPaths: showPaths),
      ),
    ),
  );
}
