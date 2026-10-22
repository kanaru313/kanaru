import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'library_database.dart';

final _log = Logger('library.missingRoots');

/// Whether a path is a folder right now. A provider so tests can answer
/// without touching the disk.
final rootIsDirectoryProvider = Provider<Future<bool> Function(String)>(
  (ref) => FileSystemEntity.isDirectory,
);

/// Paths of the library roots that are no longer folders, in root id order.
/// All roots are checked at once. A check that throws (a permission glitch,
/// say) counts as present: a folder that cannot be told apart from a missing
/// one is not worth a warning.
Future<List<String>> missingRootPaths(
  LibraryDatabase db,
  Future<bool> Function(String) isDirectory,
) async {
  final roots = await db.roots();
  final present = await Future.wait([
    for (final root in roots) _isPresent(isDirectory, root.path),
  ]);
  return [
    for (var i = 0; i < roots.length; i++)
      if (!present[i]) roots[i].path,
  ];
}

Future<bool> _isPresent(
  Future<bool> Function(String) isDirectory,
  String path,
) async {
  try {
    return await isDirectory(path);
  } catch (error) {
    _log.warning('Could not check $path', error);
    return true;
  }
}
