import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/folders/folder_disk_listing.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/enqueue_tracks.dart';
import '../../../shared/library_route_keys.dart';
import '../../../shared/play_tracks.dart';
import '../library_view_modes.dart';
import 'folder_header.dart';
import 'folder_page_parts.dart';
import 'folder_subfolders.dart';
import 'hidden_entries.dart';
import 'hidden_folder_page_provider.dart';

/// The page of a folder the library does not know (a hidden folder, or a
/// folder below one), read from the disk: every subfolder and audio file
/// directly in it, with no counts. Songs play as files outside the library.
class DiskFolderPage extends ConsumerWidget {
  const DiskFolderPage({super.key, required this.data});

  final HiddenFolderData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final modes = ref.watch(libraryViewModesProvider);
    final tracks = [for (final p in data.files) diskTrack(p)];
    final children = [
      for (final p in data.folders) diskFolderNode(p, data.rootPath),
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: FolderHeader(
            name: diskEntryName(data.path),
            path: data.path,
            onPlay: () {
              if (tracks.isNotEmpty) playTracks(ref, tracks, 0);
            },
            onShuffle: () {
              if (tracks.isNotEmpty) shuffleTracks(ref, tracks);
            },
          ),
        ),
        if (children.isNotEmpty) ...[
          FolderSectionHeading(l10n.foldersSubfolders),
          SliverSubfolders(
            children: children,
            view: modes.folders,
            onOpen: (child) => context.go(folderLocation(child.path)),
            onAction: (_, _) {},
          ),
        ],
        if (tracks.isNotEmpty) ...[
          FolderSectionHeading(l10n.foldersSongs),
          SliverList.builder(
            itemCount: tracks.length,
            itemBuilder: (context, i) => HiddenSongTile(
              path: data.files[i],
              onTap: () => playTracks(ref, tracks, i),
              onQueueAction: (action) => enqueueLoaded(ref, context, action, [
                tracks[i],
              ], tracks[i].title),
            ),
          ),
        ],
        if (tracks.isEmpty && children.isEmpty) const FolderEmptyNote(),
        folderPageEnd,
      ],
    );
  }
}
