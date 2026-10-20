import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/indexer_state.dart';
import 'package:kanaru/core/indexer/library_indexer.dart' show tagBatchSizeFor;
import 'package:kanaru/core/indexer/root_scan_result.dart';
import 'package:kanaru/core/indexer/tag_reader.dart';
import 'package:kanaru/core/indexer/walk_audio_files.dart';

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
        rootWalkerProvider.overrideWithValue((root) {
          walked.add(root);
          if (hangingWalks.contains(root)) {
            final completer = Completer<WalkResult>();
            (hungWalks[root] ??= []).add(completer);
            return completer.future;
          }
          return walkAudioFilesInIsolate(root);
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

  Future<void> settle() => Future(() {});
  int walksOf(String root) => walked.where((w) => w == root).length;

  test('a batch that was only slow frees the reader once it returns', () async {
    touch(rootA, 'fine.mp3');
    touch(rootB, 'stuck1.mp3');
    await scan();
    expect(summary().skippedRoots, {rootB: SkipReason.timedOut});

    reader.hung.single.complete([]);
    await settle();
    expect(await titles(), ['FINE.MP3'], reason: 'late result is dropped');

    final calls = reader.batches.length;
    await scan();
    expect(reader.batches.length, greaterThan(calls));
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
    await scan();
    expect(walksOf(rootA), 1);
    expect(summary().skippedRoots, isEmpty);
    expect(await titles(), ['ONE.MP3', 'TWO.MP3']);

    await scan();
    expect(walksOf(rootA), 2, reason: 'a consumed walk is not reused');
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

  test('an error in one root does not stop the others', () async {
    touch(rootA, 'one.mp3');
    touch(rootB, 'two.mp3');
    reader.failOnBatch = 1;
    await scan();

    expect(state(), isA<IndexerFailed>());
    expect(await titles(), ['TWO.MP3'], reason: 'root b was still scanned');
  });
}
