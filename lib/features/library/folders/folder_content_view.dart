import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/player/track.dart' as player;
import '../../../core/settings/library_sort.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/enqueue_tracks.dart';
import '../../../shared/library_route_keys.dart';
import '../../../shared/play_tracks.dart';
import '../../../shared/widgets/song_tile.dart';
import '../library_view_modes.dart';
import 'folder_actions.dart';
import 'folder_filter_chips.dart';
import 'folder_page_parts.dart';
import 'folder_subfolders.dart';
import 'folder_tree.dart';
import 'folders_provider.dart';

/// The body of a folder page: an optional [header], then the subfolders and
/// the songs directly in the folder.
///
/// With the tree on and both kinds present, filter chips pick folders, songs
/// or both. A grid shows the kinds under headings with counts (none while
/// filtered); a list is one continuous run of folder rows, a divider and song
/// rows. With the tree off the page is the folder's own songs only.
///
/// The filter lives in this widget's state: a folder page starts over at "All"
/// on every visit, while a page kept mounted in the shell keeps its filter.
class FolderContentView extends ConsumerStatefulWidget {
  const FolderContentView({super.key, required this.data, this.header});

  final FolderPageData data;
  final Widget? header;

  @override
  ConsumerState<FolderContentView> createState() => _FolderContentViewState();
}

/// Marks the rule between the folder rows and the songs of a list.
const folderSongsDividerKey = ValueKey('folder-songs-divider');

class _FolderContentViewState extends ConsumerState<FolderContentView> {
  FolderFilter _filter = FolderFilter.all;

  // The player tracks of the songs, rebuilt only when the song list or the
  // cover directory changes, not on every filter tap.
  List<player.Track> _tracks = const [];
  List<Object?>? _tracksOf;
  String? _tracksCoverDirectory;

  List<player.Track> _tracksFor(String? coverDirectory) {
    final songs = widget.data.songs;
    if (!identical(_tracksOf, songs) ||
        _tracksCoverDirectory != coverDirectory) {
      _tracksOf = songs;
      _tracksCoverDirectory = coverDirectory;
      _tracks = [for (final s in songs) trackFromListItem(s, coverDirectory)];
    }
    return _tracks;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final modes = ref.watch(libraryViewModesProvider);
    final coverDirectory = ref.watch(coverCacheDirectoryProvider);
    final songs = widget.data.songs;
    final tracks = _tracksFor(coverDirectory);
    final flat = !modes.foldersHierarchy;
    final children = flat ? const <FolderNode>[] : widget.data.folder.children;
    final list = modes.folders == AlbumsView.list;

    // A filter only means something while both kinds exist; after a rescan
    // removes one kind the page falls back to showing everything.
    final chips = children.isNotEmpty && songs.isNotEmpty;
    final filter = chips ? _filter : FolderFilter.all;
    final showFolders = filter != FolderFilter.songs && children.isNotEmpty;
    final showSongs = filter != FolderFilter.folders && songs.isNotEmpty;
    final headings = !list && filter == FolderFilter.all;

    return CustomScrollView(
      slivers: [
        if (widget.header != null) SliverToBoxAdapter(child: widget.header),
        if (chips)
          SliverToBoxAdapter(
            child: FolderFilterChips(
              selected: filter,
              folderCount: children.length,
              songCount: songs.length,
              onSelected: (f) => setState(() => _filter = f),
            ),
          ),
        if (showFolders) ...[
          if (headings)
            FolderSectionHeading(l10n.foldersSectionFolders(children.length)),
          SliverSubfolders(
            children: children,
            view: modes.folders,
            onOpen: (child) => context.go(folderLocation(child.path)),
            onAction: (child, action) =>
                runFolderAction(ref, context, action, child),
          ),
        ],
        if (list && showFolders && showSongs)
          const SliverToBoxAdapter(
            child: Divider(
              key: folderSongsDividerKey,
              height: 24,
              indent: 32,
              endIndent: 32,
            ),
          ),
        if (showSongs) ...[
          // The flat page has no other section, so it names its songs too.
          if (headings || flat)
            FolderSectionHeading(l10n.foldersSectionSongs(songs.length)),
          SliverList.builder(
            itemCount: tracks.length,
            itemBuilder: (context, i) => SongTile(
              song: songs[i],
              showFolder: false,
              onTap: () => playTracks(ref, tracks, i),
              onQueueAction: (action) => enqueueLoaded(ref, context, action, [
                tracks[i],
              ], tracks[i].title),
            ),
          ),
        ],
        if (songs.isEmpty && children.isEmpty) const FolderEmptyNote(),
        folderPageEnd,
      ],
    );
  }
}
