import 'dart:io';
import 'dart:isolate';

import 'audio_file_types.dart';

/// An audio file found by a walk, with what a rescan compares.
class WalkedFile {
  const WalkedFile({
    required this.path,
    required this.mtimeMs,
    required this.sizeBytes,
  });

  final String path;
  final int mtimeMs;
  final int sizeBytes;
}

/// What [walkAudioFiles] found under one root.
class WalkResult {
  const WalkResult({
    this.files = const [],
    this.unreadableDirs = const [],
    this.unstattable = const [],
    this.emptyDirs = const [],
    this.rootMissing = false,
  });

  final List<WalkedFile> files;

  /// Folders that could not be listed; what lies below them is unknown.
  final List<String> unreadableDirs;

  /// Audio-looking entries whose `stat` failed, including links whose target
  /// is unreachable (an unplugged drive); they may still exist.
  final List<String> unstattable;

  /// Folders below the root that listed with no entry at all. An unmounted
  /// mount point looks exactly like this, so what the database holds below
  /// them is unknown, like for [unreadableDirs].
  final List<String> emptyDirs;

  /// The root itself is gone or cannot be listed (unplugged drive, bad
  /// permissions).
  final bool rootMissing;
}

/// Every regular audio file under [root], recursively, with mtime and size.
///
/// Symlinks to files count (`stat` follows them); FIFOs, sockets and devices
/// do not, since opening some of them blocks forever. Broken links are not
/// files but are reported as unstattable, so their stored rows survive. Symlinked
/// folders are not followed, so link loops cannot trap the walk. Failures are
/// reported in the result, never thrown.
///
/// Synchronous I/O on purpose: it runs off the UI isolate, see
/// [walkAudioFilesInIsolate].
WalkResult walkAudioFiles(String root) {
  final files = <WalkedFile>[];
  final unreadable = <String>[];
  final unstattable = <String>[];
  final empty = <String>[];
  final pending = <String>[root];
  while (pending.isNotEmpty) {
    final dir = pending.removeLast();
    final List<FileSystemEntity> entries;
    try {
      entries = Directory(dir).listSync(followLinks: false);
    } on FileSystemException {
      if (dir == root) return const WalkResult(rootMissing: true);
      unreadable.add(dir);
      continue;
    }
    if (entries.isEmpty && dir != root) empty.add(dir);
    for (final entry in entries) {
      if (entry is Directory) {
        pending.add(entry.path);
        continue;
      }
      if (!isAudioFile(entry.path)) continue;
      final stat = FileStat.statSync(entry.path);
      if (stat.type == FileSystemEntityType.file) {
        files.add(
          WalkedFile(
            path: entry.path,
            mtimeMs: stat.modified.millisecondsSinceEpoch,
            sizeBytes: stat.size,
          ),
        );
      } else if (stat.type == FileSystemEntityType.notFound) {
        // Listed but not stat-able (raced away, broken link, unplugged
        // target): do not treat it as deleted.
        unstattable.add(entry.path);
      }
    }
  }
  return WalkResult(
    files: files,
    unreadableDirs: unreadable,
    unstattable: unstattable,
    emptyDirs: empty,
  );
}

/// [walkAudioFiles] on a worker isolate. Top-level and capturing only
/// [root], so the closure can be sent to the isolate (a closure inside a
/// notifier would capture `ref` and `this`).
Future<WalkResult> walkAudioFilesInIsolate(String root) =>
    Isolate.run(() => walkAudioFiles(root));
