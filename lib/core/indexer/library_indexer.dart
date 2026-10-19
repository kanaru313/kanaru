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

  @override
  IndexerState build() => const IndexerIdle();

  /// Starts a scan, or returns the one already running. Never throws: a
  /// failure becomes [IndexerFailed]. Does nothing without a database.
  Future<void> scan() => _running ??= _scan().whenComplete(() {
    _running = null;
  });

  Future<void> _scan() async {
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    final reader = ref.read(tagReaderProvider);
    var added = 0, updated = 0, removed = 0, failedTags = 0;
    final skipped = <String, SkipReason>{};
    final walkTime = Stopwatch(), tagTime = Stopwatch(), dbTime = Stopwatch();
    try {
      for (final root in await db.roots()) {
        state = IndexerScanning(
          phase: ScanPhase.discovering,
          rootPath: root.path,
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
        for (var i = 0; i < total; i += tagBatchSize) {
          state = IndexerScanning(
            phase: ScanPhase.reading,
            rootPath: root.path,
            done: i,
            total: total,
          );
          final end = i + tagBatchSize < total ? i + tagBatchSize : total;
          final batch = diff.toRead.sublist(i, end);
          tagTime.start();
          final tags = await reader.readBatch([for (final f in batch) f.path]);
          tagTime.stop();
          failedTags += tags.where((t) => t.error != null).length;
          dbTime.start();
          await db.upsertTracks(
            tracksFromTags(
              root.id,
              batch,
              tags,
              DateTime.now().millisecondsSinceEpoch,
            ),
          );
          dbTime.stop();
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
      state = IndexerFinished(summary);
    } catch (error, stackTrace) {
      _log.severe('Scan failed', error, stackTrace);
      state = IndexerFailed(error.toString());
    }
  }
}
