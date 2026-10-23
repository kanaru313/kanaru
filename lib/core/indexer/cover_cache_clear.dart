import 'dart:io';
import 'dart:isolate';

import 'cover_paths.dart';

/// Folder names of the thumbnail sizes inside `<cache>/covers`: the size in
/// pixels, as `resolveCoverCacheDirectory` names them.
final _sizeFolderPattern = RegExp(r'^[0-9]+$');

/// Deletes the cover thumbnails for "Clear cover cache" in Settings: those
/// of [coverDirectory] (`<cache>/covers/<size>`) and of any other size
/// folder next to it, left by an older thumbnail size. Stored cover colors
/// are not touched: their key is the hash of the original image, so the
/// thumbnails the next scan makes get the same keys and colors back.
///
/// Only real files directly inside real shard folders, named like a
/// thumbnail or a temp file, are deleted, and only those last modified
/// before [before] (a scan sharing the cache may have just written one).
/// Links are never followed. Shard folders and old size folders left empty
/// are removed; [coverDirectory] itself stays. A missing folder counts as
/// empty. Returns how many files were deleted; throws [FileSystemException]
/// when the covers folder exists but cannot be listed.
Future<int> clearCoverCache(String coverDirectory, {required DateTime before}) {
  final at = before.millisecondsSinceEpoch;
  return Isolate.run(() => _clear(coverDirectory, at));
}

int _clear(String coverDirectory, int beforeMs) {
  final before = DateTime.fromMillisecondsSinceEpoch(beforeMs);
  final current = _trimSlash(coverDirectory);
  final parent = Directory(current).parent;
  final List<FileSystemEntity> sizes;
  try {
    sizes = parent.listSync(followLinks: false);
  } on PathNotFoundException {
    return 0;
  }
  var deleted = 0;
  for (final size in sizes) {
    if (size is! Directory || !_sizeFolderPattern.hasMatch(_name(size.path))) {
      continue;
    }
    deleted += _clearSize(size, before);
    if (_trimSlash(size.path) != current) _removeIfEmpty(size);
  }
  return deleted;
}

int _clearSize(Directory size, DateTime before) {
  var deleted = 0;
  final List<FileSystemEntity> shards;
  try {
    shards = size.listSync(followLinks: false);
  } on FileSystemException {
    return 0;
  }
  for (final shard in shards) {
    final shardName = _name(shard.path);
    if (shard is! Directory || !coverShardPattern.hasMatch(shardName)) {
      continue;
    }
    final List<FileSystemEntity> files;
    try {
      files = shard.listSync(followLinks: false);
    } on FileSystemException {
      continue;
    }
    for (final file in files) {
      if (file is! File) continue;
      final name = _name(file.path);
      if (!coverFilePattern.hasMatch(name) &&
          !name.startsWith(coverTempPrefix)) {
        continue;
      }
      try {
        if (!file.statSync().modified.isBefore(before)) continue;
        file.deleteSync();
        deleted++;
      } on FileSystemException {
        // Gone already, or not ours to delete: leave it.
      }
    }
    _removeIfEmpty(shard);
  }
  return deleted;
}

/// Removes [directory] only when it is empty (never recursively).
void _removeIfEmpty(Directory directory) {
  try {
    directory.deleteSync();
  } on FileSystemException {
    // Not empty, or already gone.
  }
}

String _trimSlash(String path) => path.length > 1 && path.endsWith('/')
    ? path.substring(0, path.length - 1)
    : path;

String _name(String path) => path.substring(path.lastIndexOf('/') + 1);
