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
/// meanwhile. Errors from the reader or the database are thrown.
Future<CoverPassResult> runCoverPass({
  required LibraryDatabase db,
  required TagReader reader,
  required List<int> rootIds,
  required CoverPassProgress progress,
  required Duration timeout,
  required bool Function() shouldYield,
  required bool Function() shouldStop,
  required void Function(Future<List<TrackCover>> pending) onStuck,
}) async {
  final result = CoverPassResult();
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
      final rows = await db.tracksNeedingCover(
        rootIds,
        after: progress.cursor,
        excluding: progress.skipIds,
        limit: coverBatchSize,
      );
      if (rows.isEmpty) {
        progress.cursor = null;
        if (wrapped) {
          result.completed = true;
          return result;
        }
        wrapped = true;
        continue;
      }
      final pending = reader.readCovers([for (final (_, path) in rows) path]);
      final List<TrackCover> covers;
      try {
        covers = await pending.timeout(timeout);
      } on TimeoutException {
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
      unannounced = true;
      await db.writeCovers(writes);
      _announce(db);
      unannounced = false;
      progress.cursor = rows.last.$2;
      result.batches++;
    }
  } finally {
    // A write that went through before an error still reaches the lists.
    if (unannounced && !shouldStop()) _announce(db);
  }
}

void _announce(LibraryDatabase db) =>
    db.notifyUpdates({const TableUpdate('tracks', kind: UpdateKind.update)});
