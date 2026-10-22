import '../settings/library_scan_prefs.dart';
import 'root_path.dart';
import 'walk_audio_files.dart';

/// The rules that apply to a walk's result.
class WalkRules {
  const WalkRules({
    this.respectNomedia = false,
    this.minFileSizeBytes = 0,
    this.excludedPaths = const [],
  });

  /// Drop folders below the root that hold a `.nomedia` entry.
  final bool respectNomedia;

  /// Drop files smaller than this; 0 keeps all.
  final int minFileSizeBytes;

  /// Folders the user left out, as canonical paths. Those outside the root
  /// being scanned are ignored.
  final List<String> excludedPaths;
}

/// Every rule of a scan: the ones on files found by the walk, and the one
/// that needs the tags read.
class ScanRules {
  const ScanRules({this.walk = const WalkRules(), this.minDurationMs = 0});

  /// The rules for a scan with [prefs] and the [excluded] folders.
  factory ScanRules.from(
    LibraryScanPrefs prefs, {
    List<String> excluded = const [],
  }) => ScanRules(
    walk: WalkRules(
      respectNomedia: prefs.respectNomedia,
      minFileSizeBytes: prefs.minFileSizeKb * 1024,
      excludedPaths: excluded,
    ),
    minDurationMs: prefs.minDurationSeconds * 1000,
  );

  final WalkRules walk;

  /// Tracks shorter than this are not stored; 0 keeps all. A track without a
  /// known duration is kept.
  final int minDurationMs;
}

/// Applies [rules] to [walk] of [root]; pure, so the walk itself stays
/// ignorant of them.
///
/// Everything inside a blocked folder (an excluded folder below the root, or
/// one holding `.nomedia` when asked) leaves every list of the result, the
/// unreadable and unstattable ones too, so that rows stored below it are
/// deleted by the diff even when they cannot be listed. Files under
/// [WalkRules.minFileSizeBytes] are dropped. With [settledBeforeMs], a file
/// modified after that moment and no later than [settleUntilMs] is still
/// being written: it moves to `unstattable` (its row stays, it is not read)
/// and counts as `deferred`. A file dated after [settleUntilMs] is not being
/// written now (wrong clock, archive dates, FAT time zones), so it is read:
/// deferring it would never end.
///
/// `filteredOut` counts the files dropped and the blocked folders the walk
/// listed. With no rule at work the result is [walk] itself.
WalkResult applyWalkRules(
  WalkResult walk,
  String root,
  WalkRules rules, {
  int? settledBeforeMs,
  int? settleUntilMs,
}) {
  final blocked = <String>{
    for (final path in rules.excludedPaths)
      if (path != root && isSameOrInside(root, path)) path,
    if (rules.respectNomedia) ...walk.nomediaDirs,
  };
  if (blocked.isEmpty &&
      rules.minFileSizeBytes <= 0 &&
      settledBeforeMs == null) {
    return walk;
  }

  // Walks up from [path] to the root: no scan of every blocked folder per file.
  bool inBlocked(String path) {
    if (blocked.isEmpty) return false;
    var current = path;
    while (current.length > root.length) {
      if (blocked.contains(current)) return true;
      final slash = current.lastIndexOf('/');
      if (slash <= 0) break;
      current = current.substring(0, slash);
    }
    return false;
  }

  var dropped = 0, deferred = 0;
  final files = <WalkedFile>[];
  final unstattable = [
    for (final path in walk.unstattable)
      if (!inBlocked(path)) path,
  ];
  for (final file in walk.files) {
    if (inBlocked(file.path) || file.sizeBytes < rules.minFileSizeBytes) {
      dropped++;
    } else if (settledBeforeMs != null &&
        file.mtimeMs > settledBeforeMs &&
        (settleUntilMs == null || file.mtimeMs <= settleUntilMs)) {
      unstattable.add(file.path);
      deferred++;
    } else {
      files.add(file);
    }
  }
  final listed = walk.dirs.toSet();
  final blockedListed = blocked.where(listed.contains).length;
  return walk.copyWith(
    files: files,
    unstattable: unstattable,
    unreadableDirs: [
      for (final dir in walk.unreadableDirs)
        if (!inBlocked(dir)) dir,
    ],
    emptyDirs: [
      for (final dir in walk.emptyDirs)
        if (!inBlocked(dir)) dir,
    ],
    dirs: [
      for (final dir in walk.dirs)
        if (!inBlocked(dir)) dir,
    ],
    filteredOut: walk.filteredOut + dropped + blockedListed,
    deferred: walk.deferred + deferred,
  );
}
