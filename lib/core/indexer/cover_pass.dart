import 'dart:async';

import 'package:drift/drift.dart' show TableUpdate, UpdateKind;
import 'package:logging/logging.dart';

import '../database/library_database.dart';
import 'cover_paths.dart';
import 'tag_reader.dart';

final _log = Logger('indexer.covers');

/// Files whose covers are made per round trip. Small, so a rescan that asks
/// the pass to yield waits about a second, not the time of a large batch;
/// larger batches were not measurably faster.
const coverBatchSize = 32;

/// Where the cover pass got to in this app session, kept by the indexer
/// between passes so a pass that yields resumes instead of starting over,
/// and so files whose cover failed are not tried again by every pass.
class CoverPassProgress {
  /// Path of the last file a pass reached; the next pass starts after it.
  /// Null when the last pass completed (the next one starts at the top).
  String? cursor;

  /// Tracks whose cover failed (or timed out) in this session. Passed over
  /// until the user asks for a scan.
  final Set<int> skipIds = {};
}

/// How one cover pass ended.
class CoverPassResult {
  CoverPassResult();

  int found = 0, none = 0, failed = 0, skipped = 0, batches = 0;

  /// Every eligible track was looked at; false when the pass stopped early.
  bool completed = false;

  /// Why the pass stopped early, for the log.
  String? stoppedBecause;

  /// Time spent waiting for the native reader (finding covers and writing
  /// thumbnails), and in the database (the `tracksNeedingCover` query and
  /// `writeCovers`). Together with the pass's wall time they show which side
  /// a slow pass is on.
  Duration nativeTime = Duration.zero, dbTime = Duration.zero;
}

/// Makes the covers of the tracks under [rootIds] whose cover was not looked
/// for under the current rules, [coverBatchSize] files at a time in path
/// order, resuming at [progress]. Each batch is written silently and then
/// announced with one table update, so open lists reload at their own pace.
///
/// Stops between batches when [shouldStop] (the app is closing) or, once at
/// least one batch is done, when [shouldYield] (a rescan is waiting). A batch
/// that outlasts [timeout] stops the pass: its tracks are skipped for the
/// session and [onStuck] gets the native call, which may still return.
/// Started past the top, the pass wraps around once to pick up tracks reset
/// meanwhile. [onProgress] gets (tracks looked at, tracks waiting when the
/// pass started) before the first batch and after each one, only when there
/// is something to do. Errors from the reader or the database are thrown.
Future<CoverPassResult> runCoverPass({
  required LibraryDatabase db,
  required TagReader reader,
  required List<int> rootIds,
  required CoverPassProgress progress,
  required Duration timeout,
  required bool Function() shouldYield,
  required bool Function() shouldStop,
  required void Function(Future<List<TrackCover>> pending) onStuck,
  void Function(int done, int total)? onProgress,
}) async {
  final result = CoverPassResult();
  var done = 0, total = 0;
  if (onProgress != null) {
    // Tracks that failed earlier in this session are passed over.
    total = await db.countTracksNeedingCover(
      rootIds,
      excluding: progress.skipIds,
    );
    if (total > 0) onProgress(0, total);
  }
  var wrapped = progress.cursor == null;
  var unannounced = false;
  try {
    while (true) {
      if (shouldStop()) {
        result.stoppedBecause = 'app closing';
        return result;
      }
      if (result.batches > 0 && shouldYield()) {
        result.stoppedBecause = 'rescan requested';
        return result;
      }
      final queryTime = Stopwatch()..start();
      final rows = await db.tracksNeedingCover(
        rootIds,
        after: progress.cursor,
        excluding: progress.skipIds,
        limit: coverBatchSize,
      );
      result.dbTime += queryTime.elapsed;
      if (rows.isEmpty) {
        progress.cursor = null;
        if (wrapped) {
          result.completed = true;
          return result;
        }
        wrapped = true;
        continue;
      }
      final nativeTime = Stopwatch()..start();
      final pending = reader.readCovers([for (final (_, path) in rows) path]);
      final List<TrackCover> covers;
      try {
        covers = await pending.timeout(timeout);
        result.nativeTime += nativeTime.elapsed;
      } on TimeoutException {
        result.nativeTime += nativeTime.elapsed;
        progress.skipIds.addAll([for (final (id, _) in rows) id]);
        progress.cursor = rows.last.$2;
        onStuck(pending);
        result.stoppedBecause = 'cover batch took over $timeout';
        return result;
      }
      final byPath = {for (final cover in covers) cover.path: cover};
      final writes = <(int, String?)>[];
      for (final (id, path) in rows) {
        final cover = byPath[path];
        switch (cover?.status) {
          case CoverStatus.found when isCoverKey(cover!.cover ?? ''):
            writes.add((id, cover.cover));
            result.found++;
          case CoverStatus.none:
            writes.add((id, null));
            result.none++;
          case CoverStatus.skipped:
            result.skipped++;
          case CoverStatus.found:
            _log.warning('Malformed cover key for $path: ${cover!.cover}');
            progress.skipIds.add(id);
            result.failed++;
          case CoverStatus.failed || null:
            progress.skipIds.add(id);
            result.failed++;
        }
      }
      if (writes.isNotEmpty) {
        unannounced = true;
        final writeTime = Stopwatch()..start();
        await db.writeCovers(writes);
        result.dbTime += writeTime.elapsed;
        _announce(db);
        unannounced = false;
      }
      progress.cursor = rows.last.$2;
      result.batches++;
      done += rows.length;
      if (total > 0) onProgress?.call(done, total);
    }
  } finally {
    // A write that went through before an error still reaches the lists.
    if (unannounced && !shouldStop()) _announce(db);
  }
}

void _announce(LibraryDatabase db) =>
    db.notifyUpdates({const TableUpdate('tracks', kind: UpdateKind.update)});
