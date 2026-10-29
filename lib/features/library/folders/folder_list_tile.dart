import 'package:material_ui/material_ui.dart';

import '../../../shared/icons/app_icons.dart';
import 'folder_art.dart';
import 'folder_counts_line.dart';
import 'folder_menu.dart';
import 'folder_tree.dart';

/// One folder row: folder art, [title] (the folder name, or its label in
/// the flat list) and the counts line.
class FolderListTile extends StatelessWidget {
  const FolderListTile({
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

  /// Shows the full path under the name, for music folders that share one.
  final bool showPath;

  /// A dim line under the name (the flat list: the folders above it).
  final String? parentLine;

  /// Shows the folder's own songs only: art, count and menu (the flat list).
  final bool direct;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<FolderAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final counts = FolderCountsLine(
      folder: folder,
      directSongs: direct ? folder.directSongs : null,
    );
    final line = parentLine ?? (showPath ? folder.path : null);
    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      leading: FolderArt(folder: folder, size: 48, direct: direct),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: line == null
          ? counts
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line, maxLines: 1, overflow: TextOverflow.ellipsis),
                counts,
              ],
            ),
      trailing: const Icon(AppIcons.chevronRight),
      onTap: onTap,
    );
    return folderTileMenu(
      folder: folder,
      direct: direct,
      onAction: onAction,
      child: tile,
    );
  }
}
