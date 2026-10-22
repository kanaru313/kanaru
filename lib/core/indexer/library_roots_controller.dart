import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/cover_color_queries.dart';
import '../database/library_database.dart';
import '../database/library_root_queries.dart';
import '../database/library_startup.dart';
import '../settings/settings_provider.dart';
import 'cover_cache_cleanup.dart';
import 'cover_pass_state.dart';
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

/// Outcome of [LibraryRootsController.removeRoot] and
/// [LibraryRootsController.replaceRoot].
class RootChangeResult {
  const RootChangeResult({this.rejection, this.unchanged = false});

  /// Why nothing was changed; `null` on success.
  final RootRejection? rejection;

  /// The new path is the one the root already has: nothing was written.
  final bool unchanged;

  bool get ok => rejection == null;
}

/// Adds, removes and re-points library source folders. Calls run one after
/// the other. It never starts a scan; the caller does.
class LibraryRootsController {
  LibraryRootsController(this._ref);

  final Ref _ref;

  /// Tail of the calls so far: each call starts after the previous one is
  /// done, so it checks against the roots that call stored (two overlapping
  /// calls would both pass the check and store a duplicate or nested root).
  Future<void> _queue = Future.value();

  /// Adds the valid [paths] in one transaction. A path is refused when it is
  /// not an existing folder, is `/`, or equals, contains or lies inside a
  /// stored root or another path of the same call. Paths are canonicalised
  /// (symlinks resolved, no trailing slash) before comparing and storing.
  ///
  /// Never throws: when the database fails, every path not stored is refused
  /// with [RootRejection.writeFailed] and the error is logged.
  Future<AddRootsResult> addRoots(List<String> paths) {
    return _chain(() => _addRoots(paths));
  }

  /// Removes root [id] with its tracks. Idempotent: a root that is already
  /// gone counts as removed. Never throws.
  ///
  /// No scan follows a removal, so it cleans up itself: the stored colors no
  /// track points at any more, and the thumbnails only this root's tracks
  /// used (unless a cover pass is running: it may be writing one of them for
  /// another root, and the scan's own cleanup comes after it). A failed
  /// cleanup is logged; the next scan's cleanup catches up.
  Future<RootChangeResult> removeRoot(int id) => _chain(() async {
    final db = _ref.read(libraryDatabaseProvider);
    if (db == null) {
      return const RootChangeResult(
        rejection: RootRejection.libraryUnavailable,
      );
    }
    final coverDirectory = _ref.read(coverCacheDirectoryProvider);
    final startedAt = DateTime.now();
    var rootKeys = const <String>{};
    if (coverDirectory != null) {
      try {
        rootKeys = await db.coverKeysOfRoot(id);
      } catch (error, stackTrace) {
        _log.warning(
          'Could not list the covers of a folder',
          error,
          stackTrace,
        );
      }
    }
    try {
      await db.removeRoot(id);
    } catch (error, stackTrace) {
      _log.severe('Could not remove library folder', error, stackTrace);
      return const RootChangeResult(rejection: RootRejection.writeFailed);
    }
    await _deleteOrphanColors(db);
    if (coverDirectory != null && rootKeys.isNotEmpty) {
      await _deleteRootThumbnails(db, coverDirectory, rootKeys, startedAt);
    }
    // The root is gone for good; failing to learn whether it was the last
    // one must not report the removal as failed.
    try {
      await _syncHasRoots(db);
    } catch (error, stackTrace) {
      _log.warning('Could not refresh the has-roots flag', error, stackTrace);
    }
    return const RootChangeResult();
  });

  /// Re-points root [id] to [newPath] (removes it and adds the new folder in
  /// one transaction; the new root gets a new id). The same checks as
  /// [addRoots] apply, except against the root being replaced, so a parent or
  /// child folder of it is fine. An unknown [id] gives
  /// [RootRejection.notFound]. Never throws.
  ///
  /// The colors no track points at any more are deleted; the thumbnails are
  /// left for the scan the caller runs next (the new folder often holds the
  /// same files, and the scan's cleanup deletes what is left over).
  Future<RootChangeResult> replaceRoot(int id, String newPath) =>
      _chain(() async {
        final db = _ref.read(libraryDatabaseProvider);
        if (db == null) {
          return const RootChangeResult(
            rejection: RootRejection.libraryUnavailable,
          );
        }
        try {
          final roots = await db.roots();
          final old = roots.where((root) => root.id == id).firstOrNull;
          if (old == null) {
            return const RootChangeResult(rejection: RootRejection.notFound);
          }
          final result = await canonicalizeRoot(newPath);
          final canonical = result.path;
          if (canonical == null) {
            return RootChangeResult(rejection: result.rejection);
          }
          if (canonical == old.path) {
            return const RootChangeResult(unchanged: true);
          }
          final conflict = conflictWith(canonical, [
            for (final root in roots)
              if (root.id != id) root.path,
          ]);
          if (conflict != null) return RootChangeResult(rejection: conflict);
          await db.replaceRoot(
            id,
            canonical,
            now: DateTime.now().millisecondsSinceEpoch,
          );
          _ref.read(libraryHasRootsProvider.notifier).markPresent();
          _ref.read(settingsProvider.notifier).markLibraryOnboarded();
        } catch (error, stackTrace) {
          _log.severe('Could not replace library folder', error, stackTrace);
          return const RootChangeResult(rejection: RootRejection.writeFailed);
        }
        await _deleteOrphanColors(db);
        return const RootChangeResult();
      });

  /// Deletes the stored colors no track points at; never throws.
  Future<void> _deleteOrphanColors(LibraryDatabase db) async {
    try {
      await db.deleteOrphanCoverColors();
    } catch (error, stackTrace) {
      _log.warning('Could not delete unused cover colors', error, stackTrace);
    }
  }

  /// Deletes the thumbnails of [rootKeys] no track points at any more,
  /// unless a cover pass is running; never throws.
  Future<void> _deleteRootThumbnails(
    LibraryDatabase db,
    String directory,
    Set<String> rootKeys,
    DateTime before,
  ) async {
    if (_ref.read(coverPassProvider) is CoverPassRunning) return;
    try {
      final unused = rootKeys.difference(await db.coverKeysInUse());
      final deleted = await deleteUnusedThumbnails(
        directory,
        unused,
        before: before,
      );
      if (deleted > 0) _log.info('Deleted $deleted unused cover thumbnails');
    } catch (error, stackTrace) {
      _log.warning('Could not delete unused thumbnails', error, stackTrace);
    }
  }

  Future<void> _syncHasRoots(LibraryDatabase db) async {
    if (!await db.hasLibraryRoots()) {
      _ref.read(libraryHasRootsProvider.notifier).markAbsent();
    }
  }

  /// Runs [action] after the calls so far; [action] must not throw.
  Future<T> _chain<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<AddRootsResult> _addRoots(List<String> paths) async {
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
        _ref.read(settingsProvider.notifier).markLibraryOnboarded();
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
