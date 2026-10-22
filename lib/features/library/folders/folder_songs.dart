import '../../../core/database/folder_queries.dart';
import '../../../core/database/library_database.dart';
import '../../../shared/natural_compare.dart';

/// The songs under [dir] (see `folderTracks`), in natural order of their
/// path below it, folder by folder: the order of the tree.
Future<List<TrackListItem>> readFolderSongs(
  LibraryDatabase db,
  String dir, {
  required bool recursive,
}) async => sortByNaturalPath(
  await db.folderTracks(dir, recursive: recursive),
  (song) => song.path.substring(dir.length + 1),
);
