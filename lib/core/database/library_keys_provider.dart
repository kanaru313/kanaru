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

/// Where the first key backfill of the session stands.
enum KeysPhase {
  /// The count of rows needing keys is not back yet. Lists must not query
  /// (they would read unkeyed rows) and show their ordinary loading state.
  unknown,

  /// Rows are being keyed: lists show the "Updating library" state.
  updating,

  /// Every track has current keys (or the backfill gave up); lists that sort
  /// and group by the keys can be shown.
  ready,
}

/// Where the key backfill stands.
class LibraryKeysStatus {
  const LibraryKeysStatus({
    this.phase = KeysPhase.unknown,
    this.done = 0,
    this.total = 0,
  });

  final KeysPhase phase;
  bool get ready => phase == KeysPhase.ready;
  bool get updating => phase == KeysPhase.updating;

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
/// Starts [KeysPhase.unknown]: the browse lists wait (loading) until the
/// first count of stale rows is back, so they never read unkeyed rows. A
/// library with nothing to key (every start after the first) goes straight
/// to ready and never shows the updating state.
class LibraryKeys extends Notifier<LibraryKeysStatus> {
  bool _running = false;

  @override
  LibraryKeysStatus build() {
    final db = ref.watch(libraryDatabaseProvider);
    if (db == null) return const LibraryKeysStatus(phase: KeysPhase.ready);
    unawaited(Future.microtask(() => _run(db, first: true)));
    return const LibraryKeysStatus();
  }

  /// Keys rows a scan left without current keys (a row the first run
  /// skipped, or one it gave up on), without touching the lists' state. Call
  /// when a scan finishes; does nothing when every row is keyed or a run is
  /// already going.
  Future<void> keyStaleRows() async {
    final db = ref.read(libraryDatabaseProvider);
    if (db == null || _running || !state.ready) return;
    try {
      if (await countStaleKeys(db, textKeysVersion) == 0) return;
    } catch (error, stackTrace) {
      _log.warning('Counting unkeyed tracks failed', error, stackTrace);
      return;
    }
    if (ref.mounted && !_running) await _run(db, first: false);
  }

  /// [first]: the run that decides the phase of the lists. Later runs keep
  /// the lists as they are and only refresh them when they end.
  Future<void> _run(LibraryDatabase db, {required bool first}) async {
    _running = true;
    try {
      await _attempts(db, first: first);
    } finally {
      _running = false;
    }
    if (!ref.mounted) return;
    // Also after giving up, so the app stays usable on what is stored.
    if (first) {
      state = LibraryKeysStatus(
        phase: KeysPhase.ready,
        done: state.total,
        total: state.total,
      );
    }
  }

  Future<void> _attempts(LibraryDatabase db, {required bool first}) async {
    final delay = ref.read(libraryKeysRetryDelayProvider);
    for (var attempt = 1; attempt <= keysAttempts; attempt++) {
      try {
        await ref.read(libraryKeysRunnerProvider)(db, (done, total) {
          if (!first || !ref.mounted || total == 0) return;
          // Rows added during the run can push done past the first count.
          state = LibraryKeysStatus(
            phase: KeysPhase.updating,
            done: min(done, total),
            total: total,
          );
        });
        return;
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
  }
}

final libraryKeysProvider = NotifierProvider<LibraryKeys, LibraryKeysStatus>(
  LibraryKeys.new,
);

/// Whether the browse lists may query and show; see
/// [LibraryKeysStatus.ready]. Lists watch it, so becoming ready starts a
/// fresh load.
final keysReadyProvider = Provider<bool>(
  (ref) => ref.watch(libraryKeysProvider.select((s) => s.ready)),
);

/// Whether the "Updating library" state shows (not the plain loading state).
final keysUpdatingProvider = Provider<bool>(
  (ref) => ref.watch(libraryKeysProvider.select((s) => s.updating)),
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
