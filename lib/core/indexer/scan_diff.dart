import '../database/library_rows.dart';
import 'walk_audio_files.dart';

/// What a rescan of one root has to do.
class ScanDiff {
  const ScanDiff({
    this.toRead = const [],
    this.toDelete = const [],
    this.added = 0,
    this.updated = 0,
    this.rootEmpty = false,
  });

  /// New or changed files, whose tags must be (re)read.
  final List<WalkedFile> toRead;

  /// Ids of tracks that are gone for sure.
  final List<int> toDelete;

  /// How many of [toRead] are new, and how many replace a changed track.
  /// Unchanged tracks read again after an earlier failure are in neither.
  final int added;
  final int updated;

  /// The walk found no audio file although the database has tracks of this
  /// root (for example an empty mount point). Nothing is deleted.
  final bool rootEmpty;
}

/// Compares a [walk] with the tracks already stored for the same root.
///
/// A file is unchanged when both mtime and size match. A stored track that
/// the walk did not see is deleted only when it is certainly gone: not under
/// an unreadable or empty folder (an unmounted mount point lists as empty),
/// not unstattable, the root is present, and the walk found at least one
/// file. A missing root deletes nothing and reads nothing. An unchanged file
/// whose tags failed to read last time is read again.
ScanDiff diffScan(WalkResult walk, List<TrackSnapshot> existing) {
  if (walk.rootMissing) return const ScanDiff();

  final known = {for (final track in existing) track.path: track};
  final toRead = <WalkedFile>[];
  var added = 0, updated = 0;
  for (final file in walk.files) {
    final track = known[file.path];
    if (track == null) {
      added++;
      toRead.add(file);
    } else if (track.mtimeMs != file.mtimeMs ||
        track.sizeBytes != file.sizeBytes) {
      updated++;
      toRead.add(file);
    } else if (track.hasScanError) {
      toRead.add(file);
    }
  }

  if (walk.files.isEmpty && existing.isNotEmpty) {
    return ScanDiff(rootEmpty: true);
  }

  final seen = {for (final file in walk.files) file.path};
  final unstattable = walk.unstattable.toSet();
  final blockedDirs = [
    for (final dir in [...walk.unreadableDirs, ...walk.emptyDirs]) '$dir/',
  ];
  final toDelete = <int>[];
  for (final track in existing) {
    if (seen.contains(track.path) || unstattable.contains(track.path)) {
      continue;
    }
    if (blockedDirs.any(track.path.startsWith)) continue;
    toDelete.add(track.id);
  }
  return ScanDiff(
    toRead: toRead,
    toDelete: toDelete,
    added: added,
    updated: updated,
  );
}
