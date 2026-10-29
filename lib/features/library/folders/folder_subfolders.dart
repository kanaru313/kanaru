import 'package:material_ui/material_ui.dart';

import '../../../core/settings/library_sort.dart';
import 'folder_grid.dart';
import 'folder_list_tile.dart';
import 'folder_menu.dart';
import 'folder_tree.dart';

/// The subfolders of a folder page as a grid or a list.
class SliverSubfolders extends StatelessWidget {
  const SliverSubfolders({
    super.key,
    required this.children,
    required this.view,
    required this.onOpen,
    required this.onAction,
  });

  final List<FolderNode> children;
  final AlbumsView view;
  final void Function(FolderNode folder) onOpen;
  final void Function(FolderNode folder, FolderAction action) onAction;

  @override
  Widget build(BuildContext context) => switch (view) {
    AlbumsView.grid => SliverFolderGrid(
      folders: [
        for (final c in children)
          (folder: c, title: c.name, parentLine: null, direct: false),
      ],
      onTap: onOpen,
      onAction: onAction,
    ),
    AlbumsView.list => SliverList.builder(
      itemCount: children.length,
      itemBuilder: (context, i) => FolderListTile(
        folder: children[i],
        title: children[i].name,
        onTap: () => onOpen(children[i]),
        onAction: (action) => onAction(children[i], action),
      ),
    ),
  };
}
