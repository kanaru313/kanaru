import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../cover_colors/rust_cover_color_extractor.dart';
import '../database/excluded_folder_queries.dart';
import '../database/library_database.dart';
import '../database/library_keys_provider.dart';
import '../database/library_root_queries.dart';
import '../database/library_startup.dart';
import '../database/separator_rules_provider.dart';
import '../settings/settings_provider.dart';
import 'cover_cache_cleanup.dart';
import 'cover_pass.dart';
import 'indexer_providers.dart';
import 'indexer_state.dart';
import 'root_scan_result.dart';
import 'root_short_track_rules.dart';
import 'scan_diff.dart';
import 'scan_rules.dart';
import 'scan_stats.dart';
import 'scan_totals.dart';
import 'scanned_folders.dart';
import 'short_track_memo.dart';
import 'tag_reader.dart' show TagReader, TrackTags;
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
/// new or changed files, write them, then delete what is gone. The result is
/// published as soon as the tags are in; covers follow in a second pass.
///
/// One scan at a time, no cancelling. Batches run one after another (read
/// tags, write one transaction, next batch). Deleting happens only after all
/// batches of a root, so quitting mid-scan loses nothing.
///
/// With a cover folder, a scan first resets tracks whose thumbnail is gone,
/// then, after the tags, makes the covers of the roots that scanned without
/// error ([runCoverPass]): resumable, it yields to a requested rescan and
/// never changes the published state. A cover batch that stalls ends the
/// pass; when its native call returns, one automatic scan resumes it. When every root scanned without error
/// and the cover pass completed, it deletes thumbnails no track uses. No
/// cover step can fail the scan.
class LibraryIndexer extends Notifier<IndexerState> {
  Future<void>? _running;
  bool _rescanRequested = false;

  /// Files changed on disk since the last pass; see [scanForChanges].
  bool _changesPending = false;

  /// The running pass is for file changes only.
  bool _changeScan = false;

  /// A tag batch timed out and the native call has not returned yet. Its
  /// bridge worker stays blocked, so no further tag reads are started. Clears
  /// itself when that call finally returns (it may just have been slow).
  /// While set, roots that need a read are skipped, and so are their
  /// deletions: the root is left unchanged.
  bool _readerStuck = false;

  /// A root was left unread because of a slow read, in a scan that may
  /// arm an automatic follow-up: when the reader frees up, scan once more.
  bool _retryWhenReaderFrees = false;

  /// A cover batch timed out and its native call has not returned yet. Like
  /// [_readerStuck] but for covers only: while set, no cover pass starts;
  /// tags are still read.
  bool _coverReaderStuck = false;

  /// Where the cover pass got to, across scans of this session.
  final _coverProgress = CoverPassProgress();

  /// The running scan was started by the indexer itself (a slow walk or read
  /// finished), not by the user. Such a scan arms no further automatic scan,
  /// so a root that is slow every time costs one extra scan, not a loop.
  bool _autoStarted = false;

  /// The running scan was started with `quiet: true` and nobody asked for
  /// more since; reported on its [IndexerFinished].
  bool _quiet = false;

  /// The root whose walk the running scan is waiting for right now: a walk
  /// that finishes meanwhile is consumed by that scan itself.
  String? _awaitingWalkOf;

  /// Walks that timed out and are still running (or finished unseen), by
  /// root path. The next scan awaits the same walk instead of starting
  /// another isolate; the entry goes once a scan has consumed it.
  final Map<String, Future<WalkResult>> _abandonedWalks = {};

  /// Files found shorter than the minimum length, not read again unchanged.
  final _shortTracks = ShortTrackMemo();

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
  ///
  /// A [quiet] scan (the one at app start) marks its [IndexerFinished] so
  /// the UI can stay silent about it. A non-quiet request made while it runs
  /// makes the result count as the user's.
  Future<void> scan({bool quiet = false}) {
    if (_running == null || !quiet) _quiet = quiet;
    // Whoever asks, a scan the user wants arms automatic follow-ups again,
    // and tries the covers that failed earlier in this session once more.
    _autoStarted = false;
    _coverProgress.skipIds.clear();
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
    // Keeps `_quiet` as the scan that armed this follow-up left it: it is
    // loud only if a request for a loud scan was among those that led to it.
    if (_running == null) _autoStarted = true;
    unawaited(_startOrFollow());
  }

  /// Whether root [id] is still stored. A failing check counts as present:
  /// the caller then records the error it was already handling.
  Future<bool> _rootExistsOrUnknown(LibraryDatabase db, int id) async {
    try {
      return await db.rootExists(id);
    } catch (error, stackTrace) {
      _log.warning('Could not check root $id', error, stackTrace);
      return true;
    }
  }

  Future<void> _scanWithFollowUp() async {
    do {
      // A user's request wins over a change: its pass has no settle window.
      _changeScan = _changesPending && !_rescanRequested;
      // A pass for changes alone is quiet, whatever the pass before it was.
      if (_changeScan) _quiet = true;
      _rescanRequested = false;
      _changesPending = false;
      await _scan();
    } while ((_rescanRequested || _changesPending) && ref.mounted);
    _changeScan = false;
  }

  /// Whether a scan is running (a follow-up pass included).
  bool get isRunning => _running != null;

  /// Scans because files changed on disk (the folder watcher). Like a scan
  /// at app start it is quiet and counts as an automatic scan, and unlike
  /// [scan] it keeps the skipped covers and never asks the cover pass to
  /// yield. Files modified in the last [settleWindow] are left for the next
  /// pass. During a scan it only queues one more pass.
  Future<void> scanForChanges() {
    _changesPending = true;
    final running = _running;
    if (running != null) return running;
    _autoStarted = true;
    _quiet = true;
    return _running = _scanWithFollowUp().whenComplete(() {
      _running = null;
    });
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
    // off or the folder cannot be created: then no cover pass runs, and the
    // cache is neither repaired nor cleaned.
    final coverDir = await _usableCoverDirectory(
      ref.read(coverCacheDirectoryProvider),
    );
    final scanStartedAt = DateTime.now();
    // A scan caused by file changes leaves out files still being written.
    final settle = _changeScan
        ? (
            beforeMs:
                scanStartedAt.millisecondsSinceEpoch -
                settleWindow.inMilliseconds,
            untilMs:
                scanStartedAt.millisecondsSinceEpoch +
                settleClockSlack.inMilliseconds,
          )
        : null;
    final totals = ScanTotals(ref.read(scannedFoldersProvider).byRoot);
    int? coversRepaired;
    final okRootIds = totals.okRootIds;
    Object? firstError;
    StackTrace? firstStack;
    try {
      // Read inside the try: a scan without the exclusions would bring back
      // the tracks the user left out, so a failed read fails the scan.
      final rules = ScanRules.from(
        ref.read(settingsProvider).libraryScan,
        excluded: await db.excludedFolderPaths(),
      );
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
        // Removed since the snapshot: nothing to show, walk or warn about.
        if (!await db.rootExists(root.id)) continue;
        RootScanResult result;
        try {
          result = await _scanRoot(db, reader, root, rules, settle);
        } catch (error, stackTrace) {
          // A removed root fails on its deleted id (foreign key): not an error.
          if (!await _rootExistsOrUnknown(db, root.id)) {
            _log.info('Root removed during scan: ${root.path}');
            continue;
          }
          _log.severe('Root failed: ${root.path}', error, stackTrace);
          firstError ??= error;
          firstStack ??= stackTrace;
          result = RootScanResult.failed(error);
        }
        // Removed (or replaced) while scanning: its rows are gone, so its
        // counts and covers would describe nothing.
        if (!await db.rootExists(root.id)) {
          _log.info('Root removed during scan: ${root.path}');
          continue;
        }
        totals.add(root.id, root.path, result);
      }
      // Before anything can throw or return early: the folder watcher needs
      // the folders even when the scan failed or its covers are skipped.
      if (ref.mounted) {
        ref
            .read(scannedFoldersProvider.notifier)
            .publish(totals.folders.byRoot, deferred: totals.folders.deferred);
      }
      // Every root had its turn; now report a root that threw.
      if (firstError != null) {
        Error.throwWithStackTrace(firstError, firstStack!);
      }
      final summary = ScanSummary(
        added: totals.added,
        updated: totals.updated,
        removed: totals.removed,
        failedTags: totals.failedTags,
        undecodableNames: totals.undecodableNames,
        undecodableSampleDirs: totals.undecodableDirs,
        skippedRoots: totals.skipped,
      );
      if (totals.skippedFolderNames.isNotEmpty) {
        _log.info(
          'Folders left out of the walk: ${totals.skippedFolderNames.join(', ')}',
        );
      }
      if (totals.undecodableNames > 0) {
        _log.warning(
          '${totals.undecodableNames} files or folders skipped, names are not valid UTF-8, '
          'for example in: ${totals.undecodableDirs.join(', ')}',
        );
      }
      _log.info(
        'Scan finished: ${totals.added} added, ${totals.updated} updated, '
        '${totals.removed} removed, ${totals.failedTags} without tags, '
        '${totals.filtered} left out by scan rules, '
        '${totals.skipped.length} roots skipped; '
        'covers ${coversRepaired ?? '-'} repaired; '
        'walk ${totals.walkTime.inMilliseconds} ms, '
        'tags ${totals.tagTime.inMilliseconds} ms, '
        'db ${totals.dbTime.inMilliseconds} ms',
      );
      if (ref.mounted) {
        await ref.read(lastScanStatsProvider.notifier).publishScan(db, totals);
      }
      _publish(IndexerFinished(summary, quiet: _quiet));
    } catch (error, stackTrace) {
      _log.severe('Scan failed', error, stackTrace);
      _publish(IndexerFailed(error.toString()));
    }
    // A row the first run skipped stays hidden from Albums and Artists, and a
    // rescan does not rewrite unchanged files: key what is left, quietly.
    if (ref.mounted) {
      unawaited(ref.read(libraryKeysProvider.notifier).keyStaleRows());
    }
    if (coverDir == null || okRootIds.isEmpty || !ref.mounted) return;
    if (_coverReaderStuck) {
      _log.warning('Cover reader is stuck, covers left for a later scan');
      return;
    }
    final completed = await _coverPass(db, reader, okRootIds);
    if (completed && firstError == null && ref.mounted) {
      final removed = await _coverStep(
        'cleanup',
        () => cleanCoverCache(db, coverDir, scanStartedAt),
      );
      if (removed != null && removed > 0) {
        _log.info('Cover cache: $removed unused thumbnails removed');
      }
    }
  }

  /// Runs the cover pass for [rootIds] and logs how it went. Never throws
  /// and never touches the published state: covers can always be made
  /// later. Returns whether every eligible track was looked at.
  Future<bool> _coverPass(
    LibraryDatabase db,
    TagReader reader,
    List<int> rootIds,
  ) async {
    final elapsed = Stopwatch()..start();
    final progress = ref.read(coverPassProvider.notifier);
    final CoverPassResult r;
    try {
      r = await runCoverPass(
        db: db,
        reader: reader,
        rootIds: rootIds,
        progress: _coverProgress,
        timeout: ref.read(scanTimeoutsProvider).tagBatch,
        shouldYield: () => _rescanRequested,
        shouldStop: () => !ref.mounted,
        onStuck: (pending) {
          _coverReaderStuck = true;
          // Like a stuck tag read: once the call returns, scan once more so
          // the covers after the stalled batch get made without the user.
          // That scan keeps the skip set, and arms no retry of its own, so
          // a drive that keeps hanging costs one extra scan, not a loop.
          final retry = !_autoStarted;
          void freed() {
            _coverReaderStuck = false;
            if (retry) _scanAutomatically();
          }

          pending.then((_) => freed(), onError: (_) => freed());
        },
        onProgress: (done, total) {
          if (ref.mounted) progress.report(done, total);
        },
        // Colors from the cover: read before each batch, so turning the
        // setting off stops the color round.
        colorExtractor: ref.read(coverColorExtractorProvider),
        shouldExtractColors: () =>
            ref.mounted && ref.read(settingsProvider).display.colorFromCover,
        // The color round can be long (a whole library after turning the
        // setting on), so it also gives way to files changed on disk.
        shouldYieldColors: () => _rescanRequested || _changesPending,
      );
    } catch (error, stackTrace) {
      _log.warning('Cover pass failed', error, stackTrace);
      return false;
    } finally {
      if (ref.mounted) progress.finish();
    }
    _log.info(
      'Covers: ${r.found} found, ${r.none} without cover, '
      '${r.failed} failed, ${r.skipped} skipped; '
      '${r.batches} batches, colors ${r.colorsDone} stored, '
      '${r.colorsFailed} failed; ${elapsed.elapsedMilliseconds} ms '
      '(native ${r.nativeTime.inMilliseconds} ms, '
      'db ${r.dbTime.inMilliseconds} ms); '
      '${r.completed ? 'completed' : 'stopped: ${r.stoppedBecause}'}',
    );
    return r.completed;
  }

  /// Scans one root. Returns why it was left unfinished instead of throwing
  /// for the two stalls it handles itself: a walk or tag batch that exceeds
  /// its timeout. Anything else thrown is for the caller to record.
  Future<RootScanResult> _scanRoot(
    LibraryDatabase db,
    TagReader reader,
    LibraryRoot root,
    ScanRules rules,
    ({int beforeMs, int untilMs})? settle,
  ) async {
    final timeouts = ref.read(scanTimeoutsProvider);
    final walkFiles = ref.read(rootWalkerProvider);
    final walkTime = Stopwatch(), tagTime = Stopwatch(), dbTime = Stopwatch();
    // Known once the walk is done; carried by every result after that.
    var undecodable = 0;
    var undecodableDirs = const <String>[];
    var skippedFolders = const <String>[];
    RootScanResult stopped(SkipReason reason, {List<String>? dirs}) =>
        RootScanResult(
          dirs: dirs,
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
    WalkResult walk;
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
    final seen = walk.files.length;
    walk = applyWalkRules(
      walk,
      root.path,
      rules.walk,
      settledBeforeMs: settle?.beforeMs,
      settleUntilMs: settle?.untilMs,
    );
    undecodable = walk.undecodableNames;
    undecodableDirs = walk.undecodableSampleDirs;
    skippedFolders = walk.skippedFolderNames;
    if (walk.rootMissing) {
      _log.warning('Root unavailable, left unchanged: ${root.path}');
      return stopped(SkipReason.missing, dirs: const []);
    }
    dbTime.start();
    final snapshot = await db.trackSnapshot(root.id);
    final diff = diffScan(walk, snapshot);
    dbTime.stop();
    if (diff.rootEmpty) {
      _log.warning('Root has no audio files, left unchanged: ${root.path}');
      return stopped(SkipReason.empty, dirs: walk.dirs);
    }
    // Tracks stored under a rule that now bars them go with the diff's own
    // deletions; so do old rows of files found too short to keep.
    final shortRules = RootShortTrackRules(
      memo: _shortTracks,
      minMs: rules.minDurationMs,
      snapshot: snapshot,
    );
    final toRead = shortRules.filterToRead(diff.toRead);
    final total = toRead.length;
    if (total > 0 && _readerStuck) {
      _log.warning('Tag reader is stuck, root left unchanged: ${root.path}');
      // A walk that already outlasted its timeout is too costly to repeat:
      // keep it for the scan that can read. Scan again as soon as the reader
      // frees up.
      if (abandoned != null) _abandonedWalks[root.path] = running;
      _retryWhenReaderFrees = true;
      return stopped(SkipReason.readerStuck, dirs: walk.dirs);
    }
    var failedTags = 0, added = 0, updated = 0;
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
      final batch = toRead.sublist(i, end);
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
          undecodableNames: undecodable,
          undecodableSampleDirs: undecodableDirs,
          skippedFolderNames: skippedFolders,
          skipReason: SkipReason.timedOut,
          dirs: walk.dirs,
          deferred: walk.deferred,
          walkTime: walkTime.elapsed,
          tagTime: tagTime.elapsed,
          dbTime: dbTime.elapsed,
        );
      } finally {
        tagTime.stop();
      }
      final read = tracksFromTags(
        root.id,
        batch,
        tags,
        DateTime.now().millisecondsSinceEpoch,
      );
      final rows = shortRules.keepLongEnough(batch, read);
      // Counted from the rows: a path the reader returned nothing for is
      // stored with an error too.
      failedTags += rows.where((r) => r.scanError.value != null).length;
      dbTime.start();
      // Read per batch: rows keep the version of the rules that keyed them.
      final artistRules = ref.read(artistSplitRulesProvider);
      await db.upsertTracks(rows, artistRules: artistRules);
      dbTime.stop();
      final storedPaths = {for (final row in rows) row.path.value};
      for (final file in batch.where((f) => storedPaths.contains(f.path))) {
        if (diff.addedPaths.contains(file.path)) {
          added++;
        } else if (diff.updatedPaths.contains(file.path)) {
          updated++;
        }
      }
      _publish(reading(end));
    }
    dbTime.start();
    final deletes = await shortRules.deletes(db, root.id, diff.toDelete);
    await db.deleteTracksById(deletes);
    await db.markRootScanned(root.id, DateTime.now().millisecondsSinceEpoch);
    dbTime.stop();
    return RootScanResult(
      added: added,
      updated: updated,
      removed: deletes.length,
      filtered: walk.filteredOut,
      failedTags: failedTags,
      undecodableNames: undecodable,
      undecodableSampleDirs: undecodableDirs,
      skippedFolderNames: skippedFolders,
      dirs: walk.dirs,
      deferred: walk.deferred,
      stats: ScanStats.ofRoot(
        walk,
        seen: seen,
        tooShort: shortRules.tooShortFiles,
      ),
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
