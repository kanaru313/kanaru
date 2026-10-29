import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/player/track.dart' as player;
import '../../../l10n/l10n.dart';
import '../../../shared/enqueue_tracks.dart';
import '../../../shared/library_route_keys.dart';
import '../../../shared/play_tracks.dart';
import '../../../shared/widgets/song_tile.dart';
import '../library_view_modes.dart';
import 'folder_actions.dart';
import 'folder_counts_line.dart';
import 'folder_header.dart';
import 'folder_menu.dart';
import 'folder_page_parts.dart';
import 'folder_subfolders.dart';
import 'folder_tree.dart';
import 'folders_provider.dart';

/// The page of a folder of the library: its subfolders (with the tree on)
/// and the songs directly in it, all read from the database.
///
/// The header's Play and Shuffle are recursive, as the folder menu is: they
/// queue every library song below the folder.
class LibraryFolderPage extends ConsumerWidget {
  const LibraryFolderPage({super.key, required this.data});

  final FolderPageData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final folder = data.folder;
    final modes = ref.watch(libraryViewModesProvider);
    final coverDirectory = ref.watch(coverCacheDirectoryProvider);
    final songs = data.songs;
    final tracks = <player.Track>[
      for (final s in songs) trackFromListItem(s, coverDirectory),
    ];
    final children = modes.foldersHierarchy
        ? folder.children
        : const <FolderNode>[];
    void open(FolderNode child) => context.go(folderLocation(child.path));
    void act(FolderNode child, FolderAction action) =>
        runFolderAction(ref, context, action, child);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: FolderHeader(
            folder: folder,
            path: folder.path,
            counts: (style) => FolderCountsLine(folder: folder, style: style),
            onPlay: () =>
                runFolderAction(ref, context, FolderAction.play, folder),
            onShuffle: () =>
                runFolderAction(ref, context, FolderAction.shuffle, folder),
            trailing: [
              FolderActionsButton(
                onSelected: (action) =>
                    runFolderAction(ref, context, action, folder),
              ),
            ],
          ),
        ),
        if (children.isNotEmpty) ...[
          FolderSectionHeading(l10n.foldersSubfolders),
          SliverSubfolders(
            children: children,
            view: modes.folders,
            onOpen: open,
            onAction: act,
          ),
        ],
        if (tracks.isNotEmpty) ...[
          FolderSectionHeading(l10n.foldersSongs),
          SliverList.builder(
            itemCount: tracks.length,
            itemBuilder: (context, i) {
              void queue(action) => enqueueLoaded(ref, context, action, [
                tracks[i],
              ], tracks[i].title);
              return SongTile(
                song: songs[i],
                onTap: () => playTracks(ref, tracks, i),
                onQueueAction: queue,
              );
            },
          ),
        ],
        if (tracks.isEmpty && children.isEmpty) const FolderEmptyNote(),
        folderPageEnd,
      ],
    );
  }
}
