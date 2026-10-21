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

/// How many folders with undecodable names a walk remembers for the log.
const maxUndecodableSamples = 3;

/// Folders that hold deleted or system files, never music: trash bins,
/// `lost+found`, Synology `@eaDir`, the Windows recycle bin, and any
/// dot-folder (caches, hidden data). Only folders below the root are tested,
/// so a root that is itself a dot-folder is still walked; dot-files are not
/// affected.
bool isSkippedFolder(String path) {
  final name = path.substring(path.lastIndexOf('/') + 1);
  return name.startsWith('.') ||
      name == 'lost+found' ||
      name == '@eaDir' ||
      name.toUpperCase() == r'$RECYCLE.BIN';
}

/// What [walkAudioFiles] found under one root.
class WalkResult {
  const WalkResult({
    this.files = const [],
    this.unreadableDirs = const [],
    this.unstattable = const [],
    this.emptyDirs = const [],
    this.undecodableNames = 0,
    this.skippedFolderNames = const [],
    this.undecodableSampleDirs = const [],
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

  /// Audio files and folders whose name is not valid UTF-8 (Dart decodes it
  /// with U+FFFD, so the real entry cannot be opened by that path). They are
  /// skipped; files are also listed in [unstattable] and folders in
  /// [unreadableDirs], so stored rows survive. A name that really contains
  /// U+FFFD and opens fine is a normal entry, not counted here.
  final int undecodableNames;

  /// Up to [maxUndecodableSamples] distinct folders holding such entries.
  final List<String> undecodableSampleDirs;

  /// Distinct names of the folders [isSkippedFolder] left out, for the log.
  final List<String> skippedFolderNames;

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
  var undecodable = 0;
  final skippedNames = <String>{};
  final aliased = <String>{};
  final undecodableDirs = <String>[];
  final pending = <String>[root];
  void noteUndecodable(String dir) {
    if (undecodableDirs.length < maxUndecodableSamples &&
        !undecodableDirs.contains(dir)) {
      undecodableDirs.add(dir);
    }
  }

  while (pending.isNotEmpty) {
    final dir = pending.removeLast();
    final List<FileSystemEntity> entries;
    try {
      entries = Directory(dir).listSync(followLinks: false);
    } on FileSystemException {
      if (dir == root) return const WalkResult(rootMissing: true);
      unreadable.add(dir);
      if (dir.contains('\uFFFD')) {
        undecodable++;
        noteUndecodable(dir.substring(0, dir.lastIndexOf('/')));
      }
      continue;
    }
    if (entries.isEmpty && dir != root) empty.add(dir);
    for (final entry in entries) {
      if (entry is Directory) {
        if (isSkippedFolder(entry.path)) {
          skippedNames.add(
            entry.path.substring(entry.path.lastIndexOf('/') + 1),
          );
        } else {
          pending.add(entry.path);
        }
        continue;
      }
      if (!isAudioFile(entry.path)) continue;
      final lossy = entry.path.contains('\uFFFD');
      final stat = FileStat.statSync(entry.path);
      if (lossy && stat.type != FileSystemEntityType.file) {
        // The lossy path opens nothing: the real name is not valid UTF-8.
        undecodable++;
        unstattable.add(entry.path);
        noteUndecodable(dir);
        continue;
      }
      // Several different byte names can decode to one lossy path.
      if (lossy && !aliased.add(entry.path)) continue;
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
    skippedFolderNames: skippedNames.toList(),
    undecodableNames: undecodable,
    undecodableSampleDirs: undecodableDirs,
  );
}

/// [walkAudioFiles] on a worker isolate. Top-level and capturing only
/// [root], so the closure can be sent to the isolate (a closure inside a
/// notifier would capture `ref` and `this`).
Future<WalkResult> walkAudioFilesInIsolate(String root) =>
    Isolate.run(() => walkAudioFiles(root));
