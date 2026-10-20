import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'library_database.dart';
import 'library_keys_backfill.dart';
import 'library_startup.dart';
import 'text_keys.dart';

final _log = Logger('library.keys');

/// Where the key backfill stands.
class LibraryKeysStatus {
  const LibraryKeysStatus({this.ready = false, this.done = 0, this.total = 0});

  /// Every track has current keys (or the backfill gave up); lists that sort
  /// and group by the keys can be shown.
  final bool ready;

  /// Tracks keyed so far and tracks that needed keys when the run began; both
  /// 0 until the first count is known.
  final int done;
  final int total;

  /// 0..1, or null while the total is not known.
  double? get fraction => total == 0 ? null : (done / total).clamp(0.0, 1.0);
}

/// Runs the backfill for [db], reporting (done, total). Replaced in tests.
typedef KeysBackfillRunner = Future<void> Function(
  LibraryDatabase db,
  void Function(int done, int total) onProgress,
);

final libraryKeysRunnerProvider = Provider<KeysBackfillRunner>(
  (ref) => runKeysBackfillInBackground,
);

/// Pause before the first retry of a failed run; the second waits twice as
/// long. Tests set it to zero.
final libraryKeysRetryDelayProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);

/// Attempts at keying the library before giving up for this session.
const keysAttempts = 3;

/// Keys every track in the background. Built (and so started) once the
/// library indexer is, which is when the app shell first builds, after the
/// first frame; startup never waits for it. Playback does not depend on it.
///
/// Starts ready: a library with nothing to key (every start after the first)
/// never shows the updating state. It turns not ready only once the run
/// reports stale rows.
class LibraryKeys extends Notifier<LibraryKeysStatus> {
  @override
  LibraryKeysStatus build() {
    final db = ref.watch(libraryDatabaseProvider);
    if (db == null) return const LibraryKeysStatus(ready: true);
    unawaited(Future.microtask(() => _run(db)));
    return const LibraryKeysStatus(ready: true);
  }

  Future<void> _run(LibraryDatabase db) async {
    final delay = ref.read(libraryKeysRetryDelayProvider);
    for (var attempt = 1; attempt <= keysAttempts; attempt++) {
      try {
        await ref.read(libraryKeysRunnerProvider)(db, (done, total) {
          if (!ref.mounted || total == 0) return;
          // Rows added during the run can push done past the first count.
          state = LibraryKeysStatus(done: min(done, total), total: total);
        });
        break;
      } catch (error, stackTrace) {
        _log.severe(
          'Keying the library failed (attempt $attempt of $keysAttempts)',
          error,
          stackTrace,
        );
        if (attempt < keysAttempts) await Future<void>.delayed(delay * attempt);
        if (!ref.mounted) return;
      }
    }
    // Also after giving up, so the app stays usable on what is stored.
    if (ref.mounted) {
      state = LibraryKeysStatus(
        ready: true,
        done: state.total,
        total: state.total,
      );
    }
  }
}

final libraryKeysProvider = NotifierProvider<LibraryKeys, LibraryKeysStatus>(
  LibraryKeys.new,
);

/// Whether the browse lists may show; see [LibraryKeysStatus.ready].
final keysReadyProvider = Provider<bool>(
  (ref) => ref.watch(libraryKeysProvider.select((s) => s.ready)),
);

/// Stale rows up to which the backfill runs in place, in chunks of
/// [keysInPlaceChunkSize]. Making keys costs about 40 us a row, so a chunk
/// stays within a frame; a bigger backlog goes to an isolate.
const keysInPlaceLimit = 500;
const keysInPlaceChunkSize = 100;

/// Runs [backfillLibraryKeys] for [db]. A big backlog goes to a short-lived
/// isolate that shares the database's connection, so the UI isolate neither
/// computes keys nor holds the database. A small one, and connections that
/// cannot be shared, run in place.
Future<void> runKeysBackfillInBackground(
  LibraryDatabase db,
  void Function(int done, int total) onProgress,
) async {
  if (await countStaleKeys(db, textKeysVersion) <= keysInPlaceLimit) {
    await backfillLibraryKeys(
      db,
      chunkSize: keysInPlaceChunkSize,
      onProgress: onProgress,
    );
    return;
  }
  final port = ReceivePort();
  port.listen((message) {
    if (message case [final int done, final int total]) {
      onProgress(done, total);
    }
  });
  try {
    await db.computeWithDatabase<void, LibraryDatabase>(
      connect: LibraryDatabase.new,
      computation: _isolateComputation(port.sendPort),
    );
  } on UnsupportedError catch (_) {
    await backfillLibraryKeys(db, onProgress: onProgress);
  } finally {
    port.close();
  }
}

/// Built apart from [runKeysBackfillInBackground] so the closure that crosses
/// to the isolate captures only the port.
Future<void> Function(LibraryDatabase) _isolateComputation(SendPort port) =>
    (db) => backfillLibraryKeys(
      db,
      onProgress: (done, total) => port.send([done, total]),
    );
