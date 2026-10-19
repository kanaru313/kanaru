import 'dart:io';

/// Why a folder cannot become a library root.
enum RootRejection {
  notFound,
  notDirectory,
  duplicate,

  /// Inside an existing root, or contains one.
  nested,

  /// The library database is not available.
  libraryUnavailable,

  /// The file system root: scanning it would walk every mounted drive and
  /// pseudo file system.
  tooBroad,

  /// The database refused the write (disk full, read-only, busy).
  writeFailed,
}

/// [path] without trailing slashes; `/` stays `/`.
String stripTrailingSlash(String path) {
  var end = path.length;
  while (end > 1 && path[end - 1] == '/') {
    end--;
  }
  return path.substring(0, end);
}

/// Whether [b] is [a] or lies below it. Plain string comparison on canonical
/// paths (no SQL `LIKE`, where `%` and `_` in names are wildcards).
bool isSameOrInside(String a, String b) =>
    a == b || (a == '/' ? b.startsWith('/') : b.startsWith('$a/'));

/// The first conflict between [candidate] and [others], or `null`.
RootRejection? conflictWith(String candidate, Iterable<String> others) {
  for (final other in others) {
    if (other == candidate) return RootRejection.duplicate;
    if (isSameOrInside(other, candidate) || isSameOrInside(candidate, other)) {
      return RootRejection.nested;
    }
  }
  return null;
}

/// Resolves symlinks and strips the trailing slash of [path], which must be
/// an existing folder. Returns the canonical path or the reason it is not
/// usable (`notFound`, `notDirectory`, `tooBroad` for `/`).
Future<({String? path, RootRejection? rejection})> canonicalizeRoot(
  String path,
) async {
  try {
    final resolved = await Directory(path).resolveSymbolicLinks();
    final canonical = stripTrailingSlash(resolved);
    if (await FileSystemEntity.type(canonical) !=
        FileSystemEntityType.directory) {
      return (path: null, rejection: RootRejection.notDirectory);
    }
    if (canonical == '/') {
      return (path: null, rejection: RootRejection.tooBroad);
    }
    return (path: canonical, rejection: null);
  } on FileSystemException {
    final type = await FileSystemEntity.type(path);
    return (
      path: null,
      rejection: type == FileSystemEntityType.notFound
          ? RootRejection.notFound
          : RootRejection.notDirectory,
    );
  }
}
