import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/indexer/cover_paths.dart';
import '../../../core/player/track.dart' as player;
import '../../../core/settings/library_sort.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/enqueue_tracks.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/library_route_keys.dart';
import '../../../shared/play_tracks.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/song_tile.dart';
import '../library_detail_body.dart';
import '../library_view_modes.dart';
import 'folder_actions.dart';
import 'folder_grid_tile.dart';
import 'folder_header.dart';
import 'folder_list_tile.dart';
import 'folder_menu.dart';
import 'folder_tree.dart';
import 'folders_provider.dart';

/// One folder: header, then its subfolders (with the tree on) and the songs
/// directly in it. Tapping a song plays those songs from it. [routeKey]
/// comes from the URL; a broken key or a folder without songs shows "not
/// found".
class FolderScreen extends ConsumerWidget {
  const FolderScreen({super.key, required this.routeKey});

  final String routeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = decodeFolderRouteKey(routeKey);
    return LibraryDetailBody<FolderPageData>(
      page: path == null ? null : folderPageProvider(path),
      what: 'the folder',
      notFound: const _FolderNotFound(),
      builder: (data) => _FolderPage(data: data),
    );
  }
}

class _FolderPage extends ConsumerWidget {
  const _FolderPage({required this.data});

  final FolderPageData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final folder = data.folder;
    final songs = data.songs;
    final modes = ref.watch(libraryViewModesProvider);
    final coverDirectory = ref.watch(coverCacheDirectoryProvider);
    player.Track track(int i) => trackFromItem(
      path: songs[i].path,
      title: songs[i].title,
      artist: songs[i].artist,
      durationMs: songs[i].durationMs,
      artPath: coverPath(coverDirectory, songs[i].coverKey),
    );
    void open(FolderNode child) => context.go(folderLocation(child.path));
    void act(FolderNode child, FolderAction action) =>
        runFolderAction(ref, context, action, child);
    Widget heading(String text) => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
        child: Text(text, style: theme.textTheme.titleLarge),
      ),
    );
    final children = modes.foldersHierarchy ? folder.children : const [];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: FolderHeader(
            folder: folder,
            onAction: (action) => runFolderAction(ref, context, action, folder),
          ),
        ),
        if (children.isNotEmpty) ...[
          heading(l10n.foldersSubfolders),
          switch (modes.folders) {
            AlbumsView.grid => SliverFolderGrid(
              folders: [for (final c in children) (folder: c, title: c.name)],
              onTap: open,
              onAction: act,
            ),
            AlbumsView.list => SliverList.builder(
              itemCount: children.length,
              itemBuilder: (context, i) => FolderListTile(
                folder: children[i],
                title: children[i].name,
                onTap: () => open(children[i]),
                onAction: (action) => act(children[i], action),
              ),
            ),
          },
        ],
        if (songs.isNotEmpty) ...[
          heading(l10n.foldersSongs),
          SliverList.builder(
            itemCount: songs.length,
            itemBuilder: (context, i) => SongTile(
              song: songs[i],
              onTap: () => playTracks(ref, [
                for (var n = 0; n < songs.length; n++) track(n),
              ], i),
              onQueueAction: (action) => enqueueLoaded(ref, context, action, [
                track(i),
              ], songs[i].title),
            ),
          ),
        ],
        if (songs.isEmpty && children.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
              child: Text(
                l10n.foldersEmptyFolder,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _FolderNotFound extends StatelessWidget {
  const _FolderNotFound();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageScaffold(
      title: l10n.navFolders,
      body: EmptyState(
        icon: AppIcons.folderOutlined,
        title: l10n.foldersNotFound,
        message: l10n.foldersNotFoundMessage,
      ),
    );
  }
}
