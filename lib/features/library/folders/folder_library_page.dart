import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../shared/library_route_keys.dart';
import '../../../shared/widgets/hover_underline_links.dart';
import '../library_view_modes.dart';
import 'folder_actions.dart';
import 'folder_content_view.dart';
import 'folder_counts_line.dart';
import 'folder_header.dart';
import 'folder_menu.dart';
import 'folders_provider.dart';

/// The page of a folder of the library: its subfolders (with the tree on)
/// and the songs directly in it, all read from the database.
///
/// With the tree on, the header's Play and Shuffle and the folder menu are
/// recursive: they queue every library song below the folder, and the
/// breadcrumb links to the folders above. With it off (flat), the page is the
/// folder's own songs only: counts, art, Play, Shuffle and the menu cover just
/// those, the breadcrumb is plain text, and the menu adds "Play all below" for
/// a folder with subfolders.
class LibraryFolderPage extends ConsumerWidget {
  const LibraryFolderPage({super.key, required this.data});

  final FolderPageData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folder = data.folder;
    final modes = ref.watch(libraryViewModesProvider);
    final songs = data.songs;
    final flat = !modes.foldersHierarchy;
    final noSongs = flat && songs.isEmpty;
    void run(FolderAction action) =>
        runFolderAction(ref, context, action, folder, recursive: !flat);
    // The folders above are links in the tree view only; the current folder
    // is the page title below.
    final trail = data.trail;
    final theme = Theme.of(context);
    final breadcrumb = HoverUnderlineLinks(
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      segments: [
        for (var i = 0; i < trail.length; i++) ...[
          if (i > 0) const LinkSegment(' › '),
          LinkSegment(
            trail[i].name,
            onTap: flat || i == trail.length - 1
                ? null
                : (_) => context.go(
                    i == 0 && data.singleRoot
                        ? foldersPath
                        : folderLocation(trail[i].path),
                  ),
          ),
        ],
      ],
    );

    return FolderContentView(
      data: data,
      header: FolderHeader(
        folder: folder,
        directArt: flat,
        breadcrumb: breadcrumb,
        counts: (style) => FolderCountsLine(
          folder: folder,
          style: style,
          directSongs: flat ? songs.length : null,
        ),
        onPlay: noSongs ? null : () => run(FolderAction.play),
        onShuffle: noSongs ? null : () => run(FolderAction.shuffle),
        trailing: [
          FolderActionsButton(
            withPlayAllBelow: flat && folder.children.isNotEmpty,
            withSongActions: !noSongs,
            onSelected: run,
          ),
        ],
      ),
    );
  }
}
