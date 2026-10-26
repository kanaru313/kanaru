import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/folders/folder_disk_listing.dart';
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
import 'hidden_entries.dart';
import 'show_hidden_provider.dart';

/// The page of a folder of the library. With hidden items on it also lists,
/// from the disk, the dot-named subfolders and audio files of this folder,
/// dimmed and tagged; with them off, songs whose file name starts with a dot
/// are left out.
///
/// The header's Play and Shuffle stay database-backed and recursive, as the
/// folder menu does: they queue every library song below the folder, dot-named
/// ones included, and never the files found on the disk only; those are
/// queued from their own rows.
class LibraryFolderPage extends ConsumerWidget {
  const LibraryFolderPage({super.key, required this.data});

  final FolderPageData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final folder = data.folder;
    final modes = ref.watch(libraryViewModesProvider);
    final coverDirectory = ref.watch(coverCacheDirectoryProvider);
    final showHidden = ref.watch(showHiddenFoldersProvider);
    final onDisk = showHidden
        ? ref
                  .watch(
                    folderDiskListingProvider((
                      path: folder.path,
                      hiddenOnly: true,
                    )),
                  )
                  .value ??
              FolderDiskListing.empty
        : FolderDiskListing.empty;

    // Library songs, minus the dot-named ones while hidden items are off.
    final songs = [
      for (final s in data.songs)
        if (showHidden || !isHiddenName(s.path)) s,
    ];
    final known = {for (final s in data.songs) s.path};
    final diskFiles = sortedByName(
      onDisk.files.where((p) => !known.contains(p)),
    );
    final tracks = <player.Track>[
      for (final s in songs) trackFromListItem(s, coverDirectory),
      for (final p in diskFiles) diskTrack(p),
    ];
    final children = modes.foldersHierarchy
        ? [
            ...folder.children,
            for (final p in sortedByName(onDisk.folders))
              diskFolderNode(p, folder.rootPath),
          ]
        : const <FolderNode>[];
    void open(FolderNode child) => context.go(folderLocation(child.path));
    void act(FolderNode child, FolderAction action) =>
        runFolderAction(ref, context, action, child);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: FolderHeader(
            name: folder.name,
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
              if (i >= songs.length) {
                return HiddenSongTile(
                  path: diskFiles[i - songs.length],
                  onTap: () => playTracks(ref, tracks, i),
                  onQueueAction: queue,
                );
              }
              final tile = SongTile(
                song: songs[i],
                onTap: () => playTracks(ref, tracks, i),
                onQueueAction: queue,
              );
              return isHiddenName(songs[i].path)
                  ? HiddenSongMark(child: tile)
                  : tile;
            },
          ),
        ],
        if (tracks.isEmpty && children.isEmpty) const FolderEmptyNote(),
        folderPageEnd,
      ],
    );
  }
}
