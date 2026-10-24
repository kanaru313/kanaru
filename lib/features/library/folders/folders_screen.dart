import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/settings/library_sort.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/library_route_keys.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../library_browse_body.dart';
import '../library_view_modes.dart';
import '../widgets/page_material.dart';
import 'folder_actions.dart';
import 'folder_grid_tile.dart';
import 'folder_list_tile.dart';
import 'folder_menu.dart';
import 'folder_tree.dart';
import 'folders_provider.dart';
import 'hidden_toggle_button.dart';

final _log = Logger('library');

/// The music folders, or with the tree switched off every folder that holds
/// songs, as a list or a grid. The music folders are always listed, also
/// when there is only one. Tapping a folder opens its page.
class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    ref.listen(folderTreeProvider, (previous, next) {
      if (next.hasError && !(previous?.hasError ?? false)) {
        _log.severe('Reading the folders failed', next.error, next.stackTrace);
      }
    });
    final modes = ref.watch(libraryViewModesProvider);
    final view = modes.folders;
    final hierarchy = modes.foldersHierarchy;
    final notifier = ref.read(libraryViewModesProvider.notifier);
    final showActions =
        ref.watch(libraryDatabaseProvider) != null &&
        ref.watch(libraryHasRootsProvider);
    void open(FolderNode folder) => context.go(folderLocation(folder.path));
    void act(FolderNode folder, FolderAction action) =>
        runFolderAction(ref, context, action, folder);
    final tree = ref.watch(folderTreeProvider).value;
    String title(FolderNode folder) => hierarchy ? folder.name : folder.label;

    return PageMaterial(
      child: PageScaffold(
        title: l10n.navFolders,
        actions: [
          if (showActions) ...[
            // Hidden items are listed per folder, which only the tree has.
            if (hierarchy) const HiddenToggleButton(),
            // Both show the current setting; a tap switches it.
            IconButton(
              tooltip: hierarchy ? l10n.foldersTreeView : l10n.foldersFlatView,
              icon: Icon(hierarchy ? AppIcons.folderTree : AppIcons.folderFlat),
              onPressed: () => notifier.setFoldersHierarchy(!hierarchy),
            ),
            IconButton(
              tooltip: switch (view) {
                AlbumsView.grid => l10n.albumsGridView,
                AlbumsView.list => l10n.albumsListView,
              },
              icon: Icon(switch (view) {
                AlbumsView.grid => AppIcons.viewGrid,
                AlbumsView.list => AppIcons.viewList,
              }),
              onPressed: () => notifier.setFoldersView(switch (view) {
                AlbumsView.grid => AlbumsView.list,
                AlbumsView.list => AlbumsView.grid,
              }),
            ),
          ],
        ],
        body: LibraryBrowseBody<FolderNode>(
          hasError: ref.watch(folderTreeProvider.select((s) => s.hasError)),
          items: tree == null ? null : (hierarchy ? tree.roots : tree.flat),
          icon: AppIcons.folderOutlined,
          noRootsMessage: l10n.foldersNoRootsMessage,
          emptyTitle: l10n.foldersEmptyTitle,
          emptyMessage: l10n.foldersEmptyMessage,
          builder: (folders) => switch (view) {
            AlbumsView.grid => FolderGrid(
              folders: [for (final f in folders) (folder: f, title: title(f))],
              onTap: open,
              showPaths: true,
              onAction: act,
            ),
            AlbumsView.list => ListView.builder(
              padding: libraryListBottomPadding,
              itemCount: folders.length,
              itemBuilder: (context, i) => FolderListTile(
                folder: folders[i],
                title: title(folders[i]),
                onTap: () => open(folders[i]),
                showPath: folders[i].ambiguousRoot,
                onAction: (action) => act(folders[i], action),
              ),
            ),
          },
        ),
      ),
    );
  }
}
