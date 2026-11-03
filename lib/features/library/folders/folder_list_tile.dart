import 'package:material_ui/material_ui.dart';

import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import 'folder_art.dart';
import 'folder_counts_line.dart';
import 'folder_modal/folder_actions_region.dart';
import 'folder_modal/folder_more_button.dart';
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
    this.onQueueAction,
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

  /// Picked from the modal of a right click, long press or more button.
  final ValueChanged<QueueAction>? onQueueAction;

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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onQueueAction != null)
            FolderMoreButton(
              folder: folder,
              direct: direct,
              onQueueAction: onQueueAction!,
              showFolder: true,
            ),
          const Icon(AppIcons.chevronRight),
        ],
      ),
      onTap: onTap,
    );
    return FolderActionsRegion(
      folder: folder,
      direct: direct,
      onQueueAction: onQueueAction,
      showFolder: true,
      child: tile,
    );
  }
}
