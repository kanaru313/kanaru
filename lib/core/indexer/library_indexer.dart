import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/library_startup.dart';
import 'cover_cache_cleanup.dart';
import 'indexer_providers.dart';
import 'indexer_state.dart';
import 'tag_reader.dart' show CoverStatus;
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
///
/// With a cover folder, a scan first resets tracks whose thumbnail is gone
/// (so they are read again in that same scan) and, after every root scanned
/// without error, deletes thumbnails no track uses. Neither step can fail
/// the scan.
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
    // The folder the reader writes to. Null for this scan when covers are
    // off or the folder cannot be created: then old cover rules do not make
    // files be read again, and the cache is neither repaired nor cleaned.
    final coverDir = await _usableCoverDirectory(
      ref.read(coverCacheDirectoryProvider),
    );
    final scanStartedAt = DateTime.now();
    var added = 0, updated = 0, removed = 0, failedTags = 0, failedCovers = 0;
    int? coversRepaired, coversRemoved;
    final skipped = <String, SkipReason>{};
    final walkTime = Stopwatch(), tagTime = Stopwatch(), dbTime = Stopwatch();
    try {
      if (coverDir != null) {
        coversRepaired = await _coverStep(
          'repair',
          () => repairMissingCovers(db, coverDir),
        );
      }
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
        final diff = diffScan(
          walk,
          await db.trackSnapshot(root.id),
          coversEnabled: coverDir != null,
        );
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
          failedCovers += tags
              .where((t) => t.coverStatus == CoverStatus.failed)
              .length;
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
      if (coverDir != null) {
        coversRemoved = await _coverStep(
          'cleanup',
          () => cleanCoverCache(db, coverDir, scanStartedAt),
        );
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
        'covers ${coversRepaired ?? '-'} repaired, $failedCovers failed, '
        '${coversRemoved ?? '-'} orphans removed; '
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

  /// [directory], created if needed, or null when it is null or cannot be
  /// created (logged).
  Future<String?> _usableCoverDirectory(String? directory) async {
    if (directory == null) return null;
    try {
      await Directory(directory).create(recursive: true);
      return directory;
    } on FileSystemException catch (error) {
      _log.warning('Cover cache unavailable, covers off for this scan', error);
      return null;
    }
  }

  /// Runs a cover cache step; any error is logged and gives `null`, since
  /// the cache can always be rebuilt and must never fail a scan.
  Future<int?> _coverStep(String name, Future<int?> Function() step) async {
    try {
      return await step();
    } catch (error, stackTrace) {
      _log.warning('Cover cache $name failed', error, stackTrace);
      return null;
    }
  }
}
