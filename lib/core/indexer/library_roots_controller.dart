import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/library_startup.dart';
import 'root_path.dart';

final _log = Logger('indexer');

/// Outcome of [LibraryRootsController.addRoots].
class AddRootsResult {
  const AddRootsResult({this.added = const [], this.rejected = const {}});

  /// Canonical paths that were stored.
  final List<String> added;

  /// Input path to the reason it was refused.
  final Map<String, RootRejection> rejected;
}

/// Adds library source folders. There is deliberately no way to remove one
/// yet.
class LibraryRootsController {
  LibraryRootsController(this._ref);

  final Ref _ref;

  /// Adds the valid [paths] in one transaction. A path is refused when it is
  /// not an existing folder, is `/`, or equals, contains or lies inside a
  /// stored root or another path of the same call. Paths are canonicalised
  /// (symlinks resolved, no trailing slash) before comparing and storing.
  ///
  /// Never throws: when the database fails, every path not stored is refused
  /// with [RootRejection.writeFailed] and the error is logged.
  Future<AddRootsResult> addRoots(List<String> paths) async {
    final db = _ref.read(libraryDatabaseProvider);
    if (db == null) {
      return AddRootsResult(
        rejected: {
          for (final path in paths) path: RootRejection.libraryUnavailable,
        },
      );
    }
    final accepted = <String, String>{}; // canonical path to input path
    final rejected = <String, RootRejection>{};
    try {
      final taken = [for (final root in await db.roots()) root.path];
      for (final input in paths) {
        final result = await canonicalizeRoot(input);
        final canonical = result.path;
        if (canonical == null) {
          rejected[input] = result.rejection!;
          continue;
        }
        final conflict = conflictWith(canonical, [...taken, ...accepted.keys]);
        if (conflict != null) {
          rejected[input] = conflict;
        } else {
          accepted[canonical] = input;
        }
      }
      if (accepted.isNotEmpty) {
        await db.addRoots(
          accepted.keys.toList(),
          now: DateTime.now().millisecondsSinceEpoch,
        );
        _ref.read(libraryHasRootsProvider.notifier).markPresent();
      }
    } catch (error, stackTrace) {
      _log.severe('Could not store library folders', error, stackTrace);
      // The write is one transaction: nothing of this call was stored.
      return AddRootsResult(
        rejected: {
          ...rejected,
          for (final path in paths)
            if (!rejected.containsKey(path)) path: RootRejection.writeFailed,
        },
      );
    }
    return AddRootsResult(added: accepted.keys.toList(), rejected: rejected);
  }
}
