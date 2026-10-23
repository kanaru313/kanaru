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

/// Name of the entry that marks a folder as "no media here".
const nomediaName = '.nomedia';
const _nomediaSuffix = '/$nomediaName';

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
    this.dirs = const [],
    this.nomediaDirs = const [],
    this.filteredOut = 0,
    this.nomediaOut = 0,
    this.excludedOut = 0,
    this.tooSmallOut = 0,
    this.deferred = 0,
  });

  final List<WalkedFile> files;

  /// Every folder listed successfully, the root included.
  final List<String> dirs;

  /// Folders below the root that hold an entry named [nomediaName] (file or
  /// link). The walk always collects them; the scan rules decide whether
  /// they count.
  final List<String> nomediaDirs;

  /// Files and folders the scan rules left out of this result (set by
  /// `applyWalkRules`, never by the walk). A rescan that finds no file
  /// because of them is a deliberate filter, not an empty mount.
  final int filteredOut;

  /// Of the files in [filteredOut], those dropped for each reason (set by
  /// `applyWalkRules`): inside a folder holding `.nomedia`, inside a folder
  /// the user left out, or under the minimum size. A file inside a folder of
  /// both kinds counts for the nearest.
  final int nomediaOut, excludedOut, tooSmallOut;

  /// Files left unread for now because they changed too recently, so their
  /// stored rows stay (set by `applyWalkRules`).
  final int deferred;

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

  /// This result with the given parts replaced.
  WalkResult copyWith({
    List<WalkedFile>? files,
    List<String>? unreadableDirs,
    List<String>? unstattable,
    List<String>? emptyDirs,
    List<String>? dirs,
    int? filteredOut,
    int? nomediaOut,
    int? excludedOut,
    int? tooSmallOut,
    int? deferred,
  }) => WalkResult(
    files: files ?? this.files,
    unreadableDirs: unreadableDirs ?? this.unreadableDirs,
    unstattable: unstattable ?? this.unstattable,
    emptyDirs: emptyDirs ?? this.emptyDirs,
    undecodableNames: undecodableNames,
    skippedFolderNames: skippedFolderNames,
    undecodableSampleDirs: undecodableSampleDirs,
    rootMissing: rootMissing,
    dirs: dirs ?? this.dirs,
    nomediaDirs: nomediaDirs,
    filteredOut: filteredOut ?? this.filteredOut,
    nomediaOut: nomediaOut ?? this.nomediaOut,
    excludedOut: excludedOut ?? this.excludedOut,
    tooSmallOut: tooSmallOut ?? this.tooSmallOut,
    deferred: deferred ?? this.deferred,
  );
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
  final listed = <String>[];
  final nomedia = <String>[];
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
    listed.add(dir);
    if (entries.isEmpty && dir != root) empty.add(dir);
    var hasNomedia = false;
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
      if (!hasNomedia && entry.path.endsWith(_nomediaSuffix)) {
        hasNomedia = true;
        if (dir != root) nomedia.add(dir);
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
    dirs: listed,
    nomediaDirs: nomedia,
  );
}

/// [walkAudioFiles] on a worker isolate. Top-level and capturing only
/// [root], so the closure can be sent to the isolate (a closure inside a
/// notifier would capture `ref` and `this`).
Future<WalkResult> walkAudioFilesInIsolate(String root) =>
    Isolate.run(() => walkAudioFiles(root));
