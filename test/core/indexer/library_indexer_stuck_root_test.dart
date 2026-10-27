import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_root_queries.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/indexer_state.dart';
import 'package:kanaru/core/indexer/library_indexer.dart' show tagBatchSizeFor;
import 'package:kanaru/core/indexer/root_scan_result.dart';
import 'package:kanaru/core/indexer/tag_reader.dart';
import 'package:kanaru/core/indexer/walk_audio_files.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_tag_reader.dart';

/// Never returns for files named `stuck*`, like a native read blocked on a
/// dead disk; reads every other file like [FakeTagReader].
class _StuckTagReader extends FakeTagReader {
  /// The calls that hung, in order; complete one to let the read return.
  final hung = <Completer<List<TrackTags>>>[];

  /// Also hangs the n-th call counted from 1 (since the last [reset]).
  int? hangOnCall;

  @override
  Future<List<TrackTags>> readBatch(List<String> paths) {
    if (paths.any((p) => p.split('/').last.startsWith('stuck')) ||
        hangOnCall == batches.length + 1) {
      batches.add(List.of(paths));
      final completer = Completer<List<TrackTags>>();
      hung.add(completer);
      return completer.future;
    }
    return super.readBatch(paths);
  }
}

void main() {
  late Directory tmp;
  late String rootA, rootB;
  late LibraryDatabase db;
  late _StuckTagReader reader;
  late ProviderContainer container;
  final walked = <String>[];
  final walkedHidden = <bool>[];
  var hangingWalks = <String>{};
  final hungWalks = <String, List<Completer<WalkResult>>>{};

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('indexer_stuck_test');
    final base = tmp.resolveSymbolicLinksSync();
    rootA = '$base/a';
    rootB = '$base/b';
    Directory(rootA).createSync();
    Directory(rootB).createSync();
    db = LibraryDatabase(NativeDatabase.memory());
    reader = _StuckTagReader();
    walked.clear();
    walkedHidden.clear();
    hangingWalks = {};
    hungWalks.clear();
    container = ProviderContainer(
      overrides: [
        ...LibraryStartup(db: db).overrides,
        tagReaderProvider.overrideWithValue(reader),
        scanTimeoutsProvider.overrideWithValue(
          const ScanTimeouts(
            walk: Duration(milliseconds: 1000),
            tagBatch: Duration(milliseconds: 100),
          ),
        ),
        rootWalkerProvider.overrideWithValue((
          root, {
          required skipHiddenFolders,
        }) {
          walked.add(root);
          if (root == rootA) walkedHidden.add(skipHiddenFolders);
          if (hangingWalks.contains(root)) {
            final completer = Completer<WalkResult>();
            (hungWalks[root] ??= []).add(completer);
            return completer.future;
          }
          return walkAudioFilesInIsolate(
            root,
            skipHiddenFolders: skipHiddenFolders,
          );
        }),
      ],
    );
    await db.addRoots([rootA, rootB], now: 1);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  void touch(String root, String name) => File('$root/$name')
    ..createSync(recursive: true)
    ..writeAsStringSync('x');

  Future<void> scan() => container.read(libraryIndexerProvider.notifier).scan();
  IndexerState state() => container.read(libraryIndexerProvider);
  ScanSummary summary() => (state() as IndexerFinished).summary;
  Future<List<String>> titles() async =>
      [for (final t in await db.select(db.tracks).get()) t.title]..sort();

  test(
    'a walk that never ends fails that root, the other is scanned',
    () async {
      touch(rootA, 'one.mp3');
      touch(rootB, 'two.mp3');
      hangingWalks = {rootA};
      await scan();

      expect(state(), isA<IndexerFinished>());
      expect(summary().skippedRoots, {rootA: SkipReason.timedOut});
      expect(summary().added, 1);
      expect(await titles(), ['TWO.MP3']);
    },
  );

  test(
    'a tag batch that never returns fails that root, the earlier root '
    'stays scanned, and later roots are skipped without calling the reader',
    () async {
      touch(rootA, 'fine.mp3');
      touch(rootB, 'stuck1.mp3');
      final rootC = '${tmp.resolveSymbolicLinksSync()}/c';
      Directory(rootC).createSync();
      touch(rootC, 'other.mp3');
      await db.addRoots([rootC], now: 2);
      await scan();

      expect(state(), isA<IndexerFinished>());
      expect(summary().skippedRoots, {
        rootB: SkipReason.timedOut,
        rootC: SkipReason.readerStuck,
      });
      expect(await titles(), ['FINE.MP3']);
      expect(reader.batches, hasLength(2), reason: 'a, then the stuck b only');
    },
  );

  test('the reader stays off limits for later scans of the same session, '
      'while roots with nothing to read still finish', () async {
    touch(rootA, 'fine.mp3');
    touch(rootB, 'stuck1.mp3');
    await scan();
    final calls = reader.batches.length;

    touch(rootA, 'new.mp3');
    await scan();
    expect(reader.batches.length, calls);
    expect(summary().skippedRoots, {
      rootA: SkipReason.readerStuck,
      rootB: SkipReason.readerStuck,
    });

    // Nothing changed in a: it needs no read and is not skipped.
    File('$rootA/new.mp3').deleteSync();
    await scan();
    expect(reader.batches.length, calls);
    expect(summary().skippedRoots, {rootB: SkipReason.readerStuck});
  });

  /// Lets a scan that a finished walk or read started begin, then waits for
  /// the indexer to stop scanning. Scans the indexer starts by itself have no
  /// future to await, so the state is the only thing to watch.
  Future<void> untilIdle() async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (state() is IndexerScanning) {
      if (DateTime.now().isAfter(deadline)) fail('indexer never went idle');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  int walksOf(String root) => walked.where((w) => w == root).length;

  test('a batch that was only slow frees the reader once it returns', () async {
    touch(rootA, 'fine.mp3');
    touch(rootB, 'stuck1.mp3');
    await scan();
    expect(summary().skippedRoots, {rootB: SkipReason.timedOut});

    final calls = reader.batches.length;
    reader.hung.single.complete([]);
    await untilIdle();
    expect(await titles(), ['FINE.MP3'], reason: 'late result is dropped');
    expect(
      reader.batches.length,
      greaterThan(calls),
      reason: 'the freed reader is tried again without a user scan',
    );
  });

  test('a walk that timed out is reused by the next scan', () async {
    touch(rootA, 'one.mp3');
    touch(rootB, 'two.mp3');
    hangingWalks = {rootA};
    await scan();
    await scan();
    expect(walksOf(rootA), 1, reason: 'no second isolate for a hung root');
    expect(summary().skippedRoots, {rootA: SkipReason.timedOut});

    hungWalks[rootA]!.single.complete(await walkAudioFilesInIsolate(rootA));
    await untilIdle();
    expect(walksOf(rootA), 1);
    expect(summary().skippedRoots, isEmpty);
    expect(await titles(), ['ONE.MP3', 'TWO.MP3']);

    await scan();
    expect(walksOf(rootA), 2, reason: 'a consumed walk is not reused');
  });

  test('a walk started with the other hidden setting is not duplicated while '
      'it hangs, and the next walk uses the new setting', () async {
    touch(rootA, 'one.mp3');
    hangingWalks = {rootA};
    await scan();
    expect(walkedHidden, [true]);

    container
        .read(settingsProvider.notifier)
        .setLibraryScan(const LibraryScanPrefs(skipHiddenFolders: false));
    await scan();
    expect(walksOf(rootA), 1, reason: 'no second isolate on a hung root');
    expect(summary().skippedRoots, {rootA: SkipReason.timedOut});

    hungWalks[rootA]!.single.complete(await walkAudioFilesInIsolate(rootA));
    await untilIdle();
    expect(walksOf(rootA), 2, reason: 'the old answer is discarded');
    expect(walkedHidden, [true, false]);
  });

  test('an automatic scan abandons a walk, a user scan with the other '
      'setting arms one follow-up', () async {
    touch(rootA, 'one.mp3');
    hangingWalks = {rootA};
    await container.read(libraryIndexerProvider.notifier).scanForChanges();
    expect(walkedHidden, [true]);

    container
        .read(settingsProvider.notifier)
        .setLibraryScan(const LibraryScanPrefs(skipHiddenFolders: false));
    await scan();
    await scan();
    expect(walksOf(rootA), 1);

    hungWalks[rootA]!.single.complete(await walkAudioFilesInIsolate(rootA));
    await untilIdle();
    expect(walkedHidden, [true, false], reason: 'one follow-up, new setting');
    await untilIdle();
    expect(walkedHidden, hasLength(2));
  });

  test('a walk that finishes after its timeout starts a scan by itself, '
      'once', () async {
    touch(rootA, 'one.mp3');
    hangingWalks = {rootA};
    await scan();
    expect(summary().skippedRoots, {rootA: SkipReason.timedOut});
    expect(await titles(), isEmpty);

    hungWalks[rootA]!.single.complete(await walkAudioFilesInIsolate(rootA));
    await untilIdle();
    expect(walksOf(rootA), 1, reason: 'the finished walk is reused');
    expect(summary().skippedRoots, isEmpty);
    expect(await titles(), ['ONE.MP3']);

    await untilIdle();
    expect(walksOf(rootA), 1, reason: 'no scan after the first follow-up');
  });

  test(
    'a walk that finishes after the indexer is disposed starts nothing',
    () async {
      touch(rootA, 'one.mp3');
      hangingWalks = {rootA};
      await scan();
      final result = await walkAudioFilesInIsolate(rootA);
      container.dispose();
      hungWalks[rootA]!.single.complete(result);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(walksOf(rootA), 1);
      expect(await titles(), isEmpty);
    },
  );

  test(
    'a walk that ends while another root is being scanned is not lost',
    () async {
      touch(rootA, 'one.mp3');
      touch(rootB, 'two.mp3');
      hangingWalks = {rootA};
      await scan();
      expect(summary().skippedRoots, {rootA: SkipReason.timedOut});

      // Second scan: a is still hung and times out again, then b is slow.
      hangingWalks = {rootB};
      final second = scan();
      while (hungWalks[rootB] == null) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      hangingWalks = {};
      hungWalks[rootA]!.single.complete(await walkAudioFilesInIsolate(rootA));
      hungWalks[rootB]!.single.complete(await walkAudioFilesInIsolate(rootB));
      await second;
      await untilIdle();

      expect(summary().skippedRoots, isEmpty);
      expect(await titles(), ['ONE.MP3', 'TWO.MP3']);
      expect(walksOf(rootA), 1, reason: 'the finished walk was reused');
    },
  );

  test('automatic scans do not chain: a root that is slow inside one waits '
      'for a manual scan', () async {
    touch(rootA, 'one.mp3');
    hangingWalks = {rootA};
    await scan();
    touch(rootB, 'two.mp3');

    // The scan this starts finds b slow. That does not arm another one.
    hangingWalks = {rootB};
    hungWalks[rootA]!.single.complete(await walkAudioFilesInIsolate(rootA));
    await untilIdle();
    expect(summary().skippedRoots, {rootB: SkipReason.timedOut});
    expect(await titles(), ['ONE.MP3']);

    hangingWalks = {};
    hungWalks[rootB]!.single.complete(await walkAudioFilesInIsolate(rootB));
    await untilIdle();
    expect(await titles(), ['ONE.MP3'], reason: 'no scan on its own');

    await scan();
    expect(walksOf(rootB), 2, reason: 'a manual scan uses the finished walk');
    expect(await titles(), ['ONE.MP3', 'TWO.MP3']);
  });

  test('a root removed while its walk is hung is forgotten', () async {
    touch(rootA, 'one.mp3');
    touch(rootB, 'two.mp3');
    hangingWalks = {rootA};
    await scan();
    await (db.delete(db.libraryRoots)..where((r) => r.path.equals(rootA))).go();
    await scan();

    hungWalks[rootA]!.single.complete(await walkAudioFilesInIsolate(rootA));
    await untilIdle();
    expect(walksOf(rootA), 1);
    expect(await titles(), ['TWO.MP3']);
  });

  test('a finished walk is kept while the reader is stuck, and scanned '
      'when it frees up', () async {
    touch(rootA, 'stuck1.mp3');
    touch(rootB, 'two.mp3');
    hangingWalks = {rootB};
    await scan();
    expect(summary().skippedRoots, {
      rootA: SkipReason.timedOut,
      rootB: SkipReason.timedOut,
    });
    expect(reader.hung, hasLength(1));

    // b's walk ends while the reader is stuck on a: its scan is skipped but
    // the walk is not thrown away.
    hungWalks[rootB]!.single.complete(await walkAudioFilesInIsolate(rootB));
    await untilIdle();
    expect(walksOf(rootB), 1);
    expect(await titles(), isEmpty);

    File('$rootA/stuck1.mp3').deleteSync();
    reader.hung.single.complete([]);
    await untilIdle();
    expect(walksOf(rootB), 1, reason: 'the kept walk is used');
    expect(await titles(), ['TWO.MP3']);
  });

  group('a stuck root keeps what it already has', () {
    Future<void> seedB() async {
      touch(rootB, 'old.mp3');
      touch(rootB, 'keep.mp3');
      await scan();
      expect(await titles(), ['KEEP.MP3', 'OLD.MP3']);
      File('$rootB/old.mp3').deleteSync();
    }

    test('hung batch', () async {
      await seedB();
      touch(rootB, 'stuck1.mp3');
      await scan();
      expect(summary().skippedRoots, {rootB: SkipReason.timedOut});
      expect(summary().removed, 0);
      expect(await titles(), ['KEEP.MP3', 'OLD.MP3']);
    });

    test('hung walk', () async {
      await seedB();
      hangingWalks = {rootB};
      await scan();
      expect(summary().skippedRoots, {rootB: SkipReason.timedOut});
      expect(summary().removed, 0);
      expect(await titles(), ['KEEP.MP3', 'OLD.MP3']);
    });
  });

  test('batches written before a timeout are counted', () async {
    // Big enough for more than one batch; the first is written, the second
    // hangs.
    const files = 64;
    for (var i = 0; i < files; i++) {
      touch(rootB, 'f$i.mp3');
    }
    reader.hangOnCall = 2;
    await scan();
    expect(summary().skippedRoots, {rootB: SkipReason.timedOut});
    expect(summary().added, tagBatchSizeFor(files));
  });

  group('the automatic scan after a slow walk', () {
    Future<void> finishWalkAndWait() async {
      hungWalks[rootA]!.single.complete(await walkAudioFilesInIsolate(rootA));
      await untilIdle();
    }

    test('stays quiet when the scan that armed it was quiet', () async {
      touch(rootA, 'one.mp3');
      hangingWalks = {rootA};
      await container.read(libraryIndexerProvider.notifier).scan(quiet: true);
      expect((state() as IndexerFinished).quiet, isTrue);

      await finishWalkAndWait();

      expect(summary().added, 1);
      expect((state() as IndexerFinished).quiet, isTrue);
    });

    test('is loud when the scan that armed it was the user\'s', () async {
      touch(rootA, 'one.mp3');
      hangingWalks = {rootA};
      await scan();
      expect((state() as IndexerFinished).quiet, isFalse);

      await finishWalkAndWait();

      expect(summary().added, 1);
      expect((state() as IndexerFinished).quiet, isFalse);
    });

    test(
      'is loud when a user scan was requested during the quiet one',
      () async {
        touch(rootA, 'one.mp3');
        hangingWalks = {rootA};
        final indexer = container.read(libraryIndexerProvider.notifier);
        final quiet = indexer.scan(quiet: true);
        final user = indexer.scan();
        await Future.wait([quiet, user]);

        await finishWalkAndWait();

        expect(summary().added, 1);
        expect((state() as IndexerFinished).quiet, isFalse);
      },
    );
  });

  test('a root removed before its turn is not walked or reported', () async {
    touch(rootA, 'one.mp3');
    touch(rootB, 'two.mp3');
    final rootBId = (await db.roots()).firstWhere((r) => r.path == rootB).id;
    // Removes b while a is being walked.
    hangingWalks = {rootA};
    final done = scan();
    while (hungWalks[rootA] == null) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await db.removeRoot(rootBId);
    await done;

    expect(state(), isA<IndexerFinished>());
    expect(walksOf(rootB), 0);
    expect(summary().skippedRoots, {rootA: SkipReason.timedOut});
    expect(await titles(), isEmpty);
  });

  test('an error in one root does not stop the others', () async {
    touch(rootA, 'one.mp3');
    touch(rootB, 'two.mp3');
    reader.failOnBatch = 1;
    await scan();

    expect(state(), isA<IndexerFailed>());
    expect(await titles(), ['TWO.MP3'], reason: 'root b was still scanned');
  });
}
