import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/folder_queries.dart';
import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/throttled_tracks_query.dart';
import '../../../shared/library_browse_refresh.dart';
import 'folder_songs.dart';
import 'folder_tree.dart';

/// How many times longer than the other browse lists the folder tree waits
/// between reloads: grouping every path costs the database about a second on
/// a large library, and the page stays mounted after its first visit.
const _folderTreeIntervalFactor = 5;

/// From this many folders on the tree is built on another isolate: with
/// accents in the names, folding the names of 18k folders takes seconds.
const _treeIsolateThreshold = 2000;

/// The folders of the music folders with their recursive counts, reloaded at
/// most every [_folderTreeIntervalFactor] browse intervals while the library
/// changes. Empty when the library is unavailable.
final folderTreeProvider = StreamProvider<FolderTree>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  if (db == null) return Stream.value(FolderTree.empty);
  return throttledTracksQuery(
    db,
    () async {
      final (roots, counts) = await db.transaction(
        () async => (
          [for (final root in await db.roots()) root.path],
          await db.folderSongCounts(),
        ),
      );
      return counts.length > _treeIsolateThreshold
          ? buildFolderTreeInIsolate(roots, counts)
          : buildFolderTree(roots, counts);
    },
    interval:
        ref.watch(libraryBrowseRefreshIntervalProvider) *
        _folderTreeIntervalFactor,
  );
});

/// The songs directly in one folder (by path), in natural order of their
/// names, reloaded like the tree. Disposed when its page closes.
final folderSongsProvider = StreamProvider.autoDispose
    .family<List<TrackListItem>, String>((ref, path) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(const []);
      return throttledTracksQuery(
        db,
        () => readFolderSongs(db, path, recursive: false),
        interval: ref.watch(libraryBrowseRefreshIntervalProvider),
      );
    });

/// What a folder page shows: the folder with its counts and its direct songs.
class FolderPageData {
  const FolderPageData({required this.folder, required this.songs});

  final FolderNode folder;
  final List<TrackListItem> songs;
}

/// The page of the folder at a path: null when it holds no songs any more
/// (or never was one). Loading until both the tree and the songs are read.
final folderPageProvider = Provider.autoDispose
    .family<AsyncValue<FolderPageData?>, String>((ref, path) {
      final tree = ref.watch(folderTreeProvider);
      if (tree.hasError) return AsyncError(tree.error!, tree.stackTrace!);
      final loaded = tree.value;
      if (loaded == null) return const AsyncLoading();
      final folder = loaded.byPath[path];
      // A music folder without songs yet still opens (empty); any other
      // folder without songs is gone.
      if (folder == null || (folder.songs == 0 && !folder.isRoot)) {
        return const AsyncData(null);
      }
      final songs = ref.watch(folderSongsProvider(path));
      if (songs.hasError) return AsyncError(songs.error!, songs.stackTrace!);
      final list = songs.value;
      if (list == null) return const AsyncLoading();
      return AsyncData(FolderPageData(folder: folder, songs: list));
    });
