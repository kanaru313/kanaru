import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/library_startup.dart';
import 'root_path.dart';

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
  /// not an existing folder, or equals, contains or lies inside a stored root
  /// or another path of the same call. Paths are canonicalised (symlinks
  /// resolved, no trailing slash) before comparing and storing.
  Future<AddRootsResult> addRoots(List<String> paths) async {
    final db = _ref.read(libraryDatabaseProvider);
    if (db == null) {
      return AddRootsResult(
        rejected: {
          for (final path in paths) path: RootRejection.libraryUnavailable,
        },
      );
    }
    final taken = [for (final root in await db.roots()) root.path];
    final accepted = <String>[];
    final rejected = <String, RootRejection>{};
    for (final input in paths) {
      final result = await canonicalizeRoot(input);
      final canonical = result.path;
      if (canonical == null) {
        rejected[input] = result.rejection!;
        continue;
      }
      final conflict = conflictWith(canonical, [...taken, ...accepted]);
      if (conflict != null) {
        rejected[input] = conflict;
      } else {
        accepted.add(canonical);
      }
    }
    if (accepted.isNotEmpty) {
      await db.addRoots(accepted, now: DateTime.now().millisecondsSinceEpoch);
      _ref.read(libraryHasRootsProvider.notifier).markPresent();
    }
    return AddRootsResult(added: accepted, rejected: rejected);
  }
}
