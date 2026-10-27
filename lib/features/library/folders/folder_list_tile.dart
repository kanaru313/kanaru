import 'package:material_ui/material_ui.dart';

import '../../../shared/icons/app_icons.dart';
import 'folder_counts_line.dart';
import 'folder_menu.dart';
import 'folder_tree.dart';
import 'hidden_entries.dart';

/// One folder row: folder icon, [title] (the folder name, or its label in
/// the flat list) and the counts line.
class FolderListTile extends StatelessWidget {
  const FolderListTile({
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

  /// Shows the full path under the name, for music folders that share one.
  final bool showPath;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<FolderAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      leading: dimmedIf(
        folder.hidden,
        const SizedBox.square(
          dimension: 40,
          child: Center(child: Icon(AppIcons.folderOutlined, size: 28)),
        ),
      ),
      title: dimmedIf(
        folder.hidden,
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      subtitle: showPath
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(folder.path, maxLines: 1, overflow: TextOverflow.ellipsis),
                FolderCountsLine(folder: folder),
              ],
            )
          : FolderCountsLine(folder: folder),
      onTap: onTap,
    );
    final onAction = this.onAction;
    return onAction == null
        ? tile
        : FolderActionsRegion(onAction: onAction, child: tile);
  }
}
