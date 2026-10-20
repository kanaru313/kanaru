import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/library_database.dart';
import '../database/library_keys_provider.dart';
import '../database/library_startup.dart';
import 'cover_cache_cleanup.dart';
import 'indexer_providers.dart';
import 'indexer_state.dart';
import 'root_scan_result.dart';
import 'scan_diff.dart';
import 'tag_reader.dart' show CoverStatus, TagReader, TrackTags;
import 'tracks_from_tags.dart';
import 'walk_audio_files.dart';

final _log = Logger('indexer');

/// Bounds of the files whose tags are read and written per round trip: at
/// least enough to keep the native reader's threads busy, at most what one
/// transaction should hold.
const minTagBatchSize = 32, maxTagBatchSize = 512;

/// Progress updates a root aims for while its tags are read.
const _progressSteps = 20;

/// Batch size for [total] files to read, so the progress ring moves in
/// about [_progressSteps] steps instead of jumping from empty to full when
/// a whole library fits in one batch.
int tagBatchSizeFor(int total) =>
    (total / _progressSteps).ceil().clamp(minTagBatchSize, maxTagBatchSize);

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

  /// A tag batch timed out and the native call has not returned yet. Its
  /// bridge worker stays blocked, so no further tag reads are started. Clears
  /// itself when that call finally returns (it may just have been slow).
  /// While set, roots that need a read are skipped, and so are their
  /// deletions: the root is left unchanged.
  bool _readerStuck = false;

  /// A root was left unread because of a slow read, in a scan that may
  /// arm an automatic follow-up: when the reader frees up, scan once more.
  bool _retryWhenReaderFrees = false;

  /// The running scan was started by the indexer itself (a slow walk or read
  /// finished), not by the user. Such a scan arms no further automatic scan,
  /// so a root that is slow every time costs one extra scan, not a loop.
  bool _autoStarted = false;

  /// The root whose walk the running scan is waiting for right now: a walk
  /// that finishes meanwhile is consumed by that scan itself.
  String? _awaitingWalkOf;

  /// Walks that timed out and are still running (or finished unseen), by
  /// root path. The next scan awaits the same walk instead of starting
  /// another isolate; the entry goes once a scan has consumed it.
  final Map<String, Future<WalkResult>> _abandonedWalks = {};

  @override
  IndexerState build() {
    // Starts keying the library in the background; see `LibraryKeys`.
    ref.read(libraryKeysProvider);
    return const IndexerIdle();
  }

  /// Starts a scan, or asks the running one for a follow-up pass and returns
  /// its future (which completes after that pass). The extra pass makes sure
  /// a root added while scanning is scanned too. Never throws: a failure
  /// becomes [IndexerFailed]. Does nothing without a database.
  Future<void> scan() {
    // Whoever asks, a scan the user wants arms automatic follow-ups again.
    _autoStarted = false;
    return _startOrFollow();
  }

  Future<void> _startOrFollow() {
    final running = _running;
    if (running != null) {
      _rescanRequested = true;
      return running;
    }
    return _running = _scanWithFollowUp().whenComplete(() {
      _running = null;
    });
  }

  /// Scans because something slow has finished, unless the app is closing.
  /// A scan already running gets a follow-up pass instead.
  void _scanAutomatically() {
    if (!ref.mounted) return;
    if (_running == null) _autoStarted = true;
    unawaited(_startOrFollow());
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
    var undecodableNames = 0;
    final undecodableDirs = <String>[];
    final skippedFolderNames = <String>{};
    Object? firstError;
    StackTrace? firstStack;
    var walkTime = Duration.zero, tagTime = Duration.zero;
    var dbTime = Duration.zero;
    try {
      if (coverDir != null) {
        coversRepaired = await _coverStep(
          'repair',
          () => repairMissingCovers(db, coverDir),
        );
      }
      final roots = await db.roots();
      // A root removed since its walk timed out has nothing to wait for.
      final rootPaths = {for (final root in roots) root.path};
      _abandonedWalks.removeWhere((path, _) => !rootPaths.contains(path));
      for (final root in roots) {
        // Disposed mid-scan (the app quit): nothing left to publish to.
        if (!ref.mounted) break;
        RootScanResult result;
        try {
          result = await _scanRoot(db, reader, coverDir, root);
        } catch (error, stackTrace) {
          _log.severe('Root failed: ${root.path}', error, stackTrace);
          firstError ??= error;
          firstStack ??= stackTrace;
          result = RootScanResult.failed(error);
        }
        added += result.added;
        updated += result.updated;
        removed += result.removed;
        failedTags += result.failedTags;
        failedCovers += result.failedCovers;
        undecodableNames += result.undecodableNames;
        skippedFolderNames.addAll(result.skippedFolderNames);
        for (final dir in result.undecodableSampleDirs) {
          if (undecodableDirs.length < maxUndecodableSamples) {
            undecodableDirs.add(dir);
          }
        }
        walkTime += result.walkTime;
        tagTime += result.tagTime;
        dbTime += result.dbTime;
        final reason = result.skipReason;
        if (reason != null) skipped[root.path] = reason;
      }
      // Every root had its turn; now report a root that threw.
      if (firstError != null) {
        Error.throwWithStackTrace(firstError, firstStack!);
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
        undecodableNames: undecodableNames,
        undecodableSampleDirs: undecodableDirs,
        skippedRoots: skipped,
      );
      if (skippedFolderNames.isNotEmpty) {
        _log.info(
          'Folders left out of the walk: ${skippedFolderNames.join(', ')}',
        );
      }
      if (undecodableNames > 0) {
        _log.warning(
          '$undecodableNames files or folders skipped, names are not valid UTF-8, '
          'for example in: ${undecodableDirs.join(', ')}',
        );
      }
      _log.info(
        'Scan finished: $added added, $updated updated, $removed removed, '
        '$failedTags without tags, ${skipped.length} roots skipped; '
        'covers ${coversRepaired ?? '-'} repaired, $failedCovers failed, '
        '${coversRemoved ?? '-'} orphans removed; '
        'walk ${walkTime.inMilliseconds} ms, '
        'tags ${tagTime.inMilliseconds} ms, '
        'db ${dbTime.inMilliseconds} ms',
      );
      _publish(IndexerFinished(summary));
    } catch (error, stackTrace) {
      _log.severe('Scan failed', error, stackTrace);
      _publish(IndexerFailed(error.toString()));
    }
    // A row the first run skipped stays hidden from Albums and Artists, and a
    // rescan does not rewrite unchanged files: key what is left, quietly.
    if (ref.mounted) {
      unawaited(ref.read(libraryKeysProvider.notifier).keyStaleRows());
    }
  }

  /// Scans one root. Returns why it was left unfinished instead of throwing
  /// for the two stalls it handles itself: a walk or tag batch that exceeds
  /// its timeout. Anything else thrown is for the caller to record.
  Future<RootScanResult> _scanRoot(
    LibraryDatabase db,
    TagReader reader,
    String? coverDir,
    LibraryRoot root,
  ) async {
    final timeouts = ref.read(scanTimeoutsProvider);
    final walkFiles = ref.read(rootWalkerProvider);
    final walkTime = Stopwatch(), tagTime = Stopwatch(), dbTime = Stopwatch();
    // Known once the walk is done; carried by every result after that.
    var undecodable = 0;
    var undecodableDirs = const <String>[];
    var skippedFolders = const <String>[];
    RootScanResult stopped(SkipReason reason) => RootScanResult(
      undecodableNames: undecodable,
      undecodableSampleDirs: undecodableDirs,
      skippedFolderNames: skippedFolders,
      skipReason: reason,
      walkTime: walkTime.elapsed,
      tagTime: tagTime.elapsed,
      dbTime: dbTime.elapsed,
    );
    _publish(
      IndexerScanning(phase: ScanPhase.discovering, rootPath: root.path),
    );
    final WalkResult walk;
    final abandoned = _abandonedWalks[root.path];
    final running = abandoned ?? walkFiles(root.path);
    var keepWalk = false;
    walkTime.start();
    _awaitingWalkOf = root.path;
    try {
      walk = await running.timeout(timeouts.walk);
    } on TimeoutException {
      keepWalk = true;
      // Keep it: the isolate cannot be stopped, and a large cold root may
      // finish before the next scan asks.
      if (_abandonedWalks[root.path] != running) {
        _abandonedWalks[root.path] = running;
        if (!_autoStarted) _scanWhenAbandonedWalkEnds(root.path, running);
      }
      _log.warning('Walk took over ${timeouts.walk}, gave up: ${root.path}');
      return stopped(SkipReason.timedOut);
    } finally {
      walkTime.stop();
      _awaitingWalkOf = null;
      if (!keepWalk) _abandonedWalks.remove(root.path);
    }
    undecodable = walk.undecodableNames;
    undecodableDirs = walk.undecodableSampleDirs;
    skippedFolders = walk.skippedFolderNames;
    if (walk.rootMissing) {
      _log.warning('Root unavailable, left unchanged: ${root.path}');
      return stopped(SkipReason.missing);
    }
    dbTime.start();
    final snapshot = await db.trackSnapshot(root.id);
    final diff = diffScan(walk, snapshot, coversEnabled: coverDir != null);
    dbTime.stop();
    if (diff.rootEmpty) {
      _log.warning('Root has no audio files, left unchanged: ${root.path}');
      return stopped(SkipReason.empty);
    }
    final total = diff.toRead.length;
    if (total > 0 && _readerStuck) {
      _log.warning('Tag reader is stuck, root left unchanged: ${root.path}');
      // A walk that already outlasted its timeout is too costly to repeat:
      // keep it for the scan that can read. Scan again as soon as the reader
      // frees up.
      if (abandoned != null) _abandonedWalks[root.path] = running;
      _retryWhenReaderFrees = true;
      return stopped(SkipReason.readerStuck);
    }
    var failedTags = 0, failedCovers = 0, added = 0, updated = 0;
    IndexerScanning reading(int done) => IndexerScanning(
      phase: ScanPhase.reading,
      rootPath: root.path,
      done: done,
      total: total,
    );
    if (total > 0) _publish(reading(0));
    final batchSize = tagBatchSizeFor(total);
    for (var i = 0; i < total; i += batchSize) {
      final end = i + batchSize < total ? i + batchSize : total;
      final batch = diff.toRead.sublist(i, end);
      final List<TrackTags> tags;
      final pending = reader.readBatch([for (final f in batch) f.path]);
      tagTime.start();
      try {
        tags = await pending.timeout(timeouts.tagBatch);
      } on TimeoutException {
        // The native call keeps its bridge worker until it returns, which
        // may be never: hand it no more work until it does. Its result is
        // dropped; the next scan reads these files again.
        _readerStuck = true;
        if (!_autoStarted) _retryWhenReaderFrees = true;
        void freed() {
          _readerStuck = false;
          if (!_retryWhenReaderFrees) return;
          _retryWhenReaderFrees = false;
          _scanAutomatically();
        }

        pending.then((_) => freed(), onError: (_) => freed());
        _log.warning(
          'Tag batch took over ${timeouts.tagBatch}, gave up: ${root.path}',
        );
        return RootScanResult(
          added: added,
          updated: updated,
          failedTags: failedTags,
          failedCovers: failedCovers,
          undecodableNames: undecodable,
          undecodableSampleDirs: undecodableDirs,
          skippedFolderNames: skippedFolders,
          skipReason: SkipReason.timedOut,
          walkTime: walkTime.elapsed,
          tagTime: tagTime.elapsed,
          dbTime: dbTime.elapsed,
        );
      } finally {
        tagTime.stop();
      }
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
      for (final file in batch) {
        if (diff.addedPaths.contains(file.path)) {
          added++;
        } else if (diff.updatedPaths.contains(file.path)) {
          updated++;
        }
      }
      _publish(reading(end));
    }
    dbTime.start();
    await db.deleteTracksById(diff.toDelete);
    await db.markRootScanned(root.id, DateTime.now().millisecondsSinceEpoch);
    dbTime.stop();
    return RootScanResult(
      added: added,
      updated: updated,
      removed: diff.toDelete.length,
      failedTags: failedTags,
      failedCovers: failedCovers,
      undecodableNames: undecodable,
      undecodableSampleDirs: undecodableDirs,
      skippedFolderNames: skippedFolders,
      walkTime: walkTime.elapsed,
      tagTime: tagTime.elapsed,
      dbTime: dbTime.elapsed,
    );
  }

  /// A first scan of a huge library on a slow disk can outlast the walk
  /// timeout and would leave the library empty until the user rescans. When
  /// the abandoned [walk] of [rootPath] finally succeeds, scan again to
  /// consume it, unless the running scan is waiting for that very walk. A
  /// failed walk starts nothing; the next scan reports it.
  void _scanWhenAbandonedWalkEnds(String rootPath, Future<WalkResult> walk) {
    walk.then((_) {
      if (!ref.mounted || !identical(_abandonedWalks[rootPath], walk)) return;
      if (_awaitingWalkOf == rootPath) return;
      _log.info('Walk finished after its timeout, scanning: $rootPath');
      _scanAutomatically();
    }, onError: (Object _) {});
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
