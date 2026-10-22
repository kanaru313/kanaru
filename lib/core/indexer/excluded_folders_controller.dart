import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/excluded_folder_queries.dart';
import '../database/library_database.dart';
import '../database/library_startup.dart';
import 'indexer_providers.dart';
import 'root_path.dart';

final _log = Logger('indexer');

/// Why a folder cannot be excluded, beyond what makes any folder unusable
/// (see [RootRejection]).
enum ExclusionConflict {
  /// It is a library folder itself: remove that folder instead.
  sameAsRoot,

  /// It is not below any library folder, so excluding it changes nothing.
  outsideLibrary,

  /// It is already in the list.
  alreadyExcluded,
}

/// Outcome of [ExcludedFoldersController.add]; both `null` on success.
typedef ExclusionResult = ({
  RootRejection? rejection,
  ExclusionConflict? conflict,
});

const _added = (rejection: null, conflict: null);

/// The excluded folders, live; empty without a library database.
final excludedFoldersProvider = StreamProvider<List<ExcludedFolder>>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  return db == null ? Stream.value(const []) : db.watchExcludedFolders();
});

final excludedFoldersControllerProvider = Provider<ExcludedFoldersController>(
  ExcludedFoldersController.new,
);

/// Adds and removes excluded folders. Every change that is stored starts a
/// scan, so the tracks below the folder leave (or come back to) the library.
/// Calls run one after the other.
class ExcludedFoldersController {
  ExcludedFoldersController(this._ref);

  final Ref _ref;

  /// Tail of the calls so far, so two overlapping adds cannot both pass the
  /// check for a duplicate.
  Future<void> _queue = Future.value();

  /// Excludes the folder at [path] (symlinks are resolved first). Refused
  /// when it is not an existing folder, is `/`, equals a library folder, is
  /// not below one, or is already excluded. Never throws.
  Future<ExclusionResult> add(String path) => _chain(() async {
    final db = _ref.read(libraryDatabaseProvider);
    if (db == null) {
      return (rejection: RootRejection.libraryUnavailable, conflict: null);
    }
    try {
      final result = await canonicalizeRoot(path);
      final canonical = result.path;
      if (canonical == null) {
        return (rejection: result.rejection, conflict: null);
      }
      final roots = [for (final root in await db.roots()) root.path];
      if (roots.contains(canonical)) {
        return (rejection: null, conflict: ExclusionConflict.sameAsRoot);
      }
      if (!roots.any((root) => isSameOrInside(root, canonical))) {
        return (rejection: null, conflict: ExclusionConflict.outsideLibrary);
      }
      final stored = await db.addExcludedFolder(
        canonical,
        DateTime.now().millisecondsSinceEpoch,
      );
      if (!stored) {
        return (rejection: null, conflict: ExclusionConflict.alreadyExcluded);
      }
    } catch (error, stackTrace) {
      _log.severe('Could not store excluded folder', error, stackTrace);
      return (rejection: RootRejection.writeFailed, conflict: null);
    }
    _scan();
    return _added;
  });

  /// Brings back the folder of exclusion [id]; `false` when the write
  /// failed. Idempotent: an exclusion that is already gone counts as removed.
  Future<bool> remove(int id) => _chain(() async {
    final db = _ref.read(libraryDatabaseProvider);
    if (db == null) return false;
    try {
      await db.removeExcludedFolder(id);
    } catch (error, stackTrace) {
      _log.severe('Could not remove excluded folder', error, stackTrace);
      return false;
    }
    _scan();
    return true;
  });

  // Failures of the scan land in the indexer state, never in the zone.
  void _scan() => unawaited(_ref.read(libraryIndexerProvider.notifier).scan());

  /// Runs [action] after the calls so far; [action] must not throw.
  Future<T> _chain<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }
}
