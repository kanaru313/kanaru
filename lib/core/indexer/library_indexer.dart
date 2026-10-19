import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/library_startup.dart';
import 'indexer_providers.dart';
import 'indexer_state.dart';
import 'scan_diff.dart';
import 'tracks_from_tags.dart';
import 'walk_audio_files.dart';

final _log = Logger('indexer');

/// Files whose tags are read and written per round trip.
const tagBatchSize = 512;

/// Scans every library root: walk, diff against the database, read tags of
/// new or changed files, write them, then delete what is gone.
///
/// One scan at a time, no cancelling. Batches run one after another (read
/// tags, write one transaction, next batch). Deleting happens only after all
/// batches of a root, so quitting mid-scan loses nothing.
class LibraryIndexer extends Notifier<IndexerState> {
  Future<void>? _running;
  bool _rescanRequested = false;

  @override
  IndexerState build() => const IndexerIdle();

  /// Starts a scan, or asks the running one for a follow-up pass and returns
  /// its future (which completes after that pass). The extra pass makes sure
  /// a root added while scanning is scanned too. Never throws: a failure
  /// becomes [IndexerFailed]. Does nothing without a database.
  Future<void> scan() {
    final running = _running;
    if (running != null) {
      _rescanRequested = true;
      return running;
    }
    return _running = _scanWithFollowUp().whenComplete(() {
      _running = null;
    });
  }

  Future<void> _scanWithFollowUp() async {
    do {
      _rescanRequested = false;
      await _scan();
    } while (_rescanRequested && ref.mounted);
  }

  /// Publishes [next] unless the container is already disposed (the app quit
  /// while scanning).
  void _publish(IndexerState next) {
    if (ref.mounted) state = next;
  }

  Future<void> _scan() async {
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    final reader = ref.read(tagReaderProvider);
    var added = 0, updated = 0, removed = 0, failedTags = 0;
    final skipped = <String, SkipReason>{};
    final walkTime = Stopwatch(), tagTime = Stopwatch(), dbTime = Stopwatch();
    try {
      for (final root in await db.roots()) {
        _publish(
          IndexerScanning(phase: ScanPhase.discovering, rootPath: root.path),
        );
        walkTime.start();
        final walk = await walkAudioFilesInIsolate(root.path);
        walkTime.stop();
        if (walk.rootMissing) {
          skipped[root.path] = SkipReason.missing;
          _log.warning('Root unavailable, left unchanged: ${root.path}');
          continue;
        }
        dbTime.start();
        final diff = diffScan(walk, await db.trackSnapshot(root.id));
        dbTime.stop();
        if (diff.rootEmpty) {
          skipped[root.path] = SkipReason.empty;
          _log.warning('Root has no audio files, left unchanged: ${root.path}');
          continue;
        }
        added += diff.added;
        updated += diff.updated;
        final total = diff.toRead.length;
        IndexerScanning reading(int done) => IndexerScanning(
          phase: ScanPhase.reading,
          rootPath: root.path,
          done: done,
          total: total,
        );
        if (total > 0) _publish(reading(0));
        for (var i = 0; i < total; i += tagBatchSize) {
          final end = i + tagBatchSize < total ? i + tagBatchSize : total;
          final batch = diff.toRead.sublist(i, end);
          tagTime.start();
          final tags = await reader.readBatch([for (final f in batch) f.path]);
          tagTime.stop();
          final rows = tracksFromTags(
            root.id,
            batch,
            tags,
            DateTime.now().millisecondsSinceEpoch,
          );
          // Counted from the rows: a path the reader returned nothing for is
          // stored with an error too.
          failedTags += rows.where((r) => r.scanError.value != null).length;
          dbTime.start();
          await db.upsertTracks(rows);
          dbTime.stop();
          _publish(reading(end));
        }
        dbTime.start();
        await db.deleteTracksById(diff.toDelete);
        await db.markRootScanned(
          root.id,
          DateTime.now().millisecondsSinceEpoch,
        );
        dbTime.stop();
        removed += diff.toDelete.length;
      }
      final summary = ScanSummary(
        added: added,
        updated: updated,
        removed: removed,
        failedTags: failedTags,
        skippedRoots: skipped,
      );
      _log.info(
        'Scan finished: $added added, $updated updated, $removed removed, '
        '$failedTags without tags, ${skipped.length} roots skipped; '
        'walk ${walkTime.elapsedMilliseconds} ms, '
        'tags ${tagTime.elapsedMilliseconds} ms, '
        'db ${dbTime.elapsedMilliseconds} ms',
      );
      _publish(IndexerFinished(summary));
    } catch (error, stackTrace) {
      _log.severe('Scan failed', error, stackTrace);
      _publish(IndexerFailed(error.toString()));
    }
  }
}
