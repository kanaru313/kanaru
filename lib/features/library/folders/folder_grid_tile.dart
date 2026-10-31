import 'package:material_ui/material_ui.dart';

import 'folder_art.dart';
import 'folder_counts_line.dart';
import 'folder_menu.dart';
import 'folder_tree.dart';
import '../../../shared/fixed_line_strut.dart';
import '../../../shared/widgets/library_grid/library_grid_card.dart';

/// One folder in a grid: a folder frame holding one cover, [title] and the counts line.
class FolderGridTile extends StatelessWidget {
  const FolderGridTile({
    super.key,
    required this.folder,
    required this.title,
    required this.onTap,
    this.showPath = false,
    this.parentLine,
    this.direct = false,
    this.onAction,
  });

  final FolderNode folder;
  final String title;
  final VoidCallback onTap;

  /// Shows the full path as a tooltip, for music folders that share a name.
  final bool showPath;

  /// A dim line under the name (flat mode: the folders above it).
  final String? parentLine;

  /// Shows the folder's own songs only: art, count and menu (flat mode).
  final bool direct;

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
              FolderArt(
                folder: folder,
                size: constraints.maxWidth,
                direct: direct,
              ),
              const SizedBox(height: gridTileGap),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
                strutStyle: fixedLineStrut(theme.textTheme.titleSmall),
              ),
              if (parentLine != null)
                Text(
                  parentLine!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  strutStyle: fixedLineStrut(theme.textTheme.bodySmall),
                ),
              FolderCountsLine(
                folder: folder,
                directSongs: direct ? folder.directSongs : null,
              ),
            ],
          ),
        ),
      ),
    );
    if (showPath) tile = Tooltip(message: folder.path, child: tile);
    return folderTileMenu(
      folder: folder,
      direct: direct,
      onAction: onAction,
      child: tile,
    );
  }
}
