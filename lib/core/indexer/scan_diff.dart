import '../database/library_rows.dart';
import 'walk_audio_files.dart';

/// What a rescan of one root has to do.
class ScanDiff {
  const ScanDiff({
    this.toRead = const [],
    this.toDelete = const [],
    this.addedPaths = const {},
    this.updatedPaths = const {},
    this.rootEmpty = false,
  });

  /// New or changed files, whose tags must be (re)read.
  final List<WalkedFile> toRead;

  /// Ids of tracks that are gone for sure.
  final List<int> toDelete;

  /// The files of [toRead] that are new, and those that replace a changed
  /// track. Unchanged tracks read again after an earlier failure are in
  /// neither.
  final Set<String> addedPaths;
  final Set<String> updatedPaths;

  /// The walk found no audio file although the database has tracks of this
  /// root and no rule explains it (for example an empty mount point).
  /// Nothing is deleted.
  final bool rootEmpty;
}

/// Compares a [walk] with the tracks already stored for the same root.
///
/// A file is unchanged when both mtime and size match. A stored track that
/// the walk did not see is deleted only when it is certainly gone: not under
/// an unreadable or empty folder (an unmounted mount point lists as empty),
/// not unstattable, the root is present, and the walk found at least one
/// file. A missing root deletes nothing and reads nothing. An unchanged file
/// whose tags failed to read last time is read again. Covers play no part:
/// the cover pass finds them from the database.
ScanDiff diffScan(WalkResult walk, List<TrackSnapshot> existing) {
  if (walk.rootMissing) return const ScanDiff();

  final known = {for (final track in existing) track.path: track};
  final toRead = <WalkedFile>[];
  final addedPaths = <String>{}, updatedPaths = <String>{};
  for (final file in walk.files) {
    final track = known[file.path];
    if (track == null) {
      addedPaths.add(file.path);
      toRead.add(file);
    } else if (track.mtimeMs != file.mtimeMs ||
        track.sizeBytes != file.sizeBytes) {
      updatedPaths.add(file.path);
      toRead.add(file);
    } else if (track.hasScanError) {
      toRead.add(file);
    }
  }

  // A walk emptied by the user's own rules or by files still being written
  // (`filteredOut`, `deferred`) is not a mount that lists nothing: the rules
  // may delete everything. A mount point lists no folder at all, so both
  // counts are 0 there.
  if (walk.files.isEmpty &&
      existing.isNotEmpty &&
      walk.filteredOut == 0 &&
      walk.deferred == 0) {
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
    addedPaths: addedPaths,
    updatedPaths: updatedPaths,
  );
}
