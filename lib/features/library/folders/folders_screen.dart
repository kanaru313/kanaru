import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/settings/library_sort.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/library_route_keys.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../library_browse_body.dart';
import '../library_detail_body.dart';
import '../library_view_modes.dart';
import '../widgets/page_material.dart';
import 'folder_actions.dart';
import 'folder_content_view.dart';
import 'folder_grid.dart';
import 'folder_list_tile.dart';
import 'folder_menu.dart';
import 'folder_trail.dart';
import 'folder_tree.dart';
import 'folders_provider.dart';

final _log = Logger('library');

/// The music folders, or with the tree switched off every folder that holds
/// songs (named by the folder and the folders above it, standing for its own
/// songs), as a list or a grid. With the tree on and only one music folder,
/// that folder's content is shown directly. Tapping a folder opens its page.
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
        runFolderAction(ref, context, action, folder, recursive: hierarchy);
    final tree = ref.watch(folderTreeProvider).value;
    // Flat tiles are named by the folder and the folders above it, and stand
    // for their own songs only.
    FolderEntry entry(FolderNode f) => (
      folder: f,
      title: f.name,
      parentLine: hierarchy ? null : folderParentLine(f),
      direct: !hierarchy,
    );

    return PageMaterial(
      child: PageScaffold(
        title: l10n.navFolders,
        actions: [
          if (showActions) ...[
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
          builder: (folders) => hierarchy && folders.length == 1
              // The only music folder: its content stands for the screen.
              ? LibraryDetailBody<FolderPageData>(
                  page: folderPageProvider(folders.single.path),
                  what: 'the folder',
                  notFound: EmptyState(
                    icon: AppIcons.folderOutlined,
                    title: l10n.foldersEmptyTitle,
                    message: l10n.foldersEmptyMessage,
                  ),
                  builder: (data) => FolderContentView(data: data),
                )
              : switch (view) {
                  AlbumsView.grid => FolderGrid(
                    folders: [for (final f in folders) entry(f)],
                    onTap: open,
                    showPaths: true,
                    onAction: act,
                  ),
                  AlbumsView.list => ListView.builder(
                    padding: libraryListBottomPadding,
                    itemCount: folders.length,
                    itemBuilder: (context, i) => FolderListTile(
                      folder: folders[i],
                      title: folders[i].name,
                      parentLine: hierarchy
                          ? null
                          : folderParentLine(folders[i]),
                      direct: !hierarchy,
                      onTap: () => open(folders[i]),
                      showPath: hierarchy && folders[i].ambiguousRoot,
                      onAction: (action) => act(folders[i], action),
                    ),
                  ),
                },
        ),
      ),
    );
  }
}
