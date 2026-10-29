import 'package:material_ui/material_ui.dart';

import '../albums/album_grid_tile.dart';
import '../widgets/round_grid_tile.dart';
import 'folder_art.dart';
import 'folder_counts_line.dart';
import 'folder_menu.dart';
import 'folder_tree.dart';
import '../../../shared/fixed_line_strut.dart';

/// One folder in a grid: a folder frame holding one cover, [title] and the counts line.
class FolderGridTile extends StatelessWidget {
  const FolderGridTile({
    super.key,
    required this.folder,
    required this.title,
    required this.onTap,
    this.showPath = false,
    this.onAction,
  });

  final FolderNode folder;
  final String title;
  final VoidCallback onTap;

  /// Shows the full path as a tooltip, for music folders that share a name.
  final bool showPath;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<FolderAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget tile = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(gridTilePadding),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              FolderArt(folder: folder, size: constraints.maxWidth),
              const SizedBox(height: gridTileGap),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
                strutStyle: fixedLineStrut(theme.textTheme.titleSmall),
              ),
              FolderCountsLine(folder: folder),
            ],
          ),
        ),
      ),
    );
    if (showPath) tile = Tooltip(message: folder.path, child: tile);
    final onAction = this.onAction;
    return onAction == null
        ? tile
        : FolderActionsRegion(onAction: onAction, child: tile);
  }
}

/// A folder to show in [FolderGrid] or [SliverFolderGrid]: the node and the
/// name to show for it.
typedef FolderEntry = ({FolderNode folder, String title});

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
        tileHeight: roundGridTileHeight,
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
          tileHeight: roundGridTileHeight,
        ),
        itemCount: folders.length,
        itemBuilder: (context, i) =>
            _tile(folders[i], onTap, onAction, showPaths: showPaths),
      ),
    ),
  );
}
