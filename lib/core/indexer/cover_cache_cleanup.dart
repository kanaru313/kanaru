import 'dart:io';
import 'dart:isolate';

import '../database/library_database.dart';
import 'cover_paths.dart';

/// Resets every track whose cover thumbnail is gone (or empty), so the scan
/// that calls this reads those files again and rewrites the thumbnails. A
/// missing cover folder counts as every thumbnail gone: wiping the cache is
/// a normal thing to do and one rescan brings the covers back.
///
/// Returns how many keys were reset, or `null` when the folder exists but
/// cannot be listed (nothing is reset then). Throws on database errors; the
/// indexer catches them.
Future<int?> repairMissingCovers(LibraryDatabase db, String directory) async {
  final present = await Isolate.run(() => _presentKeys(directory));
  if (present == null) return null;
  final missing = (await db.coverKeysInUse()).difference(present);
  await db.resetCoverScan(missing);
  return missing.length;
}

/// Deletes the thumbnails no track points at, and leftover temp files.
///
/// Only touches real files directly inside real shard folders of
/// [directory], named like a thumbnail or a temp file; links are never
/// followed and anything else is left alone. Only files last modified before
/// [scanStartedAt] go: another process sharing the cache may have just
/// written a thumbnail it has not stored yet.
///
/// Call it only from the scan, after every root was scanned without error,
/// so the keys in use are complete. Returns how many files were deleted.
Future<int> cleanCoverCache(
  LibraryDatabase db,
  String directory,
  DateTime scanStartedAt,
) async {
  final inUse = await db.coverKeysInUse();
  return Isolate.run(() => _deleteOrphans(directory, inUse, scanStartedAt));
}

/// Keys of the non-empty thumbnails in [directory]; empty when it does not
/// exist, `null` when it cannot be listed.
Set<String>? _presentKeys(String directory) {
  final present = <String>{};
  try {
    for (final (key, file) in _thumbnails(directory)) {
      if (file.statSync().size > 0) present.add(key);
    }
  } on PathNotFoundException {
    return {};
  } on FileSystemException {
    return null;
  }
  return present;
}

int _deleteOrphans(String directory, Set<String> inUse, DateTime before) {
  var deleted = 0;
  final Iterable<(String, File)> candidates;
  try {
    candidates = _thumbnails(directory, withTemps: true).toList();
  } on FileSystemException {
    return 0;
  }
  for (final (key, file) in candidates) {
    if (inUse.contains(key)) continue;
    try {
      if (!file.statSync().modified.isBefore(before)) continue;
      file.deleteSync();
      deleted++;
    } on FileSystemException {
      // Gone already, or not ours to delete: leave it.
    }
  }
  return deleted;
}

/// `(key, file)` for each thumbnail (and with [withTemps], each temp file,
/// whose key is never in use) in the shard folders of [directory].
Iterable<(String, File)> _thumbnails(
  String directory, {
  bool withTemps = false,
}) sync* {
  final shards = Directory(directory).listSync(followLinks: false);
  for (final shard in shards) {
    final shardName = _name(shard.path);
    if (shard is! Directory || !coverShardPattern.hasMatch(shardName)) {
      continue;
    }
    for (final entry in shard.listSync(followLinks: false)) {
      if (entry is! File) continue;
      final name = _name(entry.path);
      if (coverFilePattern.hasMatch(name)) {
        yield ('$shardName/$name', entry);
      } else if (withTemps && name.startsWith(coverTempPrefix)) {
        yield ('$shardName/$name', entry);
      }
    }
  }
}

String _name(String path) => path.substring(path.lastIndexOf('/') + 1);
