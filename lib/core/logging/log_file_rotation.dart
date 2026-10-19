import 'dart:io';

/// `base` → `base.1` → … → `base.<maxFiles - 1>` in [directory], from the
/// highest number down, skipping gaps; numbers that would reach [maxFiles]
/// or beyond are deleted first. Names like `.01` are left alone.
///
/// Returns `false` when a file could not be moved. The chain then stops
/// there, since moving the next one down would overwrite a file that is
/// still in place; nothing is lost and the current file stays as it is.
/// Returns `true` when [base] was moved or did not exist.
bool rotateNumbered(String directory, String base, int maxFiles) {
  final current = File('$directory/$base');
  if (!current.existsSync()) return true;
  final numbered = RegExp('^${RegExp.escape(base)}\\.([1-9]\\d{0,3})\$');
  try {
    final kept = <int>[];
    for (final entity in Directory(directory).listSync()) {
      if (entity is! File) continue;
      final match = numbered.firstMatch(baseName(entity.path));
      if (match == null) continue;
      final n = int.parse(match[1]!);
      if (n >= maxFiles - 1) {
        _tryDelete(entity);
      } else {
        kept.add(n);
      }
    }
    kept.sort((a, b) => b.compareTo(a));
    for (final n in kept) {
      File('$directory/$base.$n').renameSync('$directory/$base.${n + 1}');
    }
    if (maxFiles > 1) {
      current.renameSync('$directory/$base.1');
    } else {
      current.deleteSync();
    }
    return true;
  } on FileSystemException {
    return false;
  }
}

/// Moves [path] to `path.1`, replacing an older backup. `true` when [path]
/// did not exist, `false` on failure.
bool keepOneBackup(String path) {
  try {
    if (!File(path).existsSync()) return true;
    File(path).renameSync('$path.1');
    return true;
  } on FileSystemException {
    return false;
  }
}

/// Keeps the files (`kanaru-<pid>.log` and its `.1` backup) of the [keep]
/// most recently written pids and deletes the rest. Never throws.
void pruneInstanceFiles(String directory, int keep) {
  final pattern = RegExp(r'^kanaru-(\d+)\.log(\.1)?$');
  final byPid = <String, List<File>>{};
  try {
    for (final entity in Directory(directory).listSync()) {
      if (entity is! File) continue;
      final match = pattern.firstMatch(baseName(entity.path));
      if (match != null) byPid.putIfAbsent(match[1]!, () => []).add(entity);
    }
  } on FileSystemException {
    return;
  }
  DateTime newest(List<File> files) => files
      .map((f) {
        try {
          return f.lastModifiedSync();
        } on FileSystemException {
          return DateTime.fromMillisecondsSinceEpoch(0);
        }
      })
      .reduce((a, b) => a.isAfter(b) ? a : b);
  final groups = byPid.values.toList()
    ..sort((a, b) => newest(b).compareTo(newest(a)));
  for (final group in groups.skip(keep)) {
    group.forEach(_tryDelete);
  }
}

/// Whether this process holds a file named one of [names] in
/// [realDirectory] that has been deleted since it was opened (Linux:
/// `/proc/self/fd` shows such a file as `<path> (deleted)`). Writing to it
/// would go nowhere, and its lock protects nothing. `false` where this
/// cannot be told.
///
/// [realDirectory] must have no symbolic links, as `/proc` shows them
/// resolved.
bool holdsDeletedFile(String realDirectory, List<String> names) {
  if (!Platform.isLinux) return false;
  final deleted = {for (final name in names) '$realDirectory/$name (deleted)'};
  try {
    for (final fd in Directory('/proc/self/fd').listSync(followLinks: false)) {
      try {
        if (deleted.contains(Link(fd.path).targetSync())) return true;
      } on FileSystemException {
        continue; // The descriptor of the listing itself, already closed.
      }
    }
  } on FileSystemException {
    return false;
  }
  return false;
}

String baseName(String path) =>
    path.substring(path.lastIndexOf(Platform.pathSeparator) + 1);

void _tryDelete(File file) {
  try {
    file.deleteSync();
  } on FileSystemException {
    // A file that cannot be deleted must not stop logging.
  }
}
