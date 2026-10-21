import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/indexer/cover_pass.dart';
import 'package:kanaru/core/indexer/tag_reader.dart';

import 'fake_tag_reader.dart';

void main() {
  late Directory tmp;
  late LibraryDatabase db;
  late FakeTagReader reader;
  late int rootId;
  late CoverPassProgress progress;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('cover_pass_test');
    db = LibraryDatabase(NativeDatabase.memory());
    reader = FakeTagReader()..coverDirectory = '${tmp.path}/covers';
    rootId = (await db.addRoots(['/m'], now: 1)).single;
    progress = CoverPassProgress();
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  /// Stores tracks `/m/<name>` not yet looked at for covers.
  Future<void> add(Iterable<String> names) => db.upsertTracks([
    for (final name in names)
      TracksCompanion.insert(
        rootId: rootId,
        path: '/m/$name',
        mtimeMs: 1,
        sizeBytes: 1,
        title: name,
        addedAt: 1,
        updatedAt: 1,
      ),
  ]);

  /// `n00.mp3` … for [count] files starting at [from].
  List<String> names(String prefix, int count, {int from = 0}) => [
    for (var i = from; i < from + count; i++)
      '$prefix${i.toString().padLeft(2, '0')}.mp3',
  ];

  Future<Map<String, String?>> keys() async => {
    for (final row in await db.select(db.tracks).get())
      row.path.substring(3): row.coverKey,
  };

  Future<CoverPassResult> pass({
    bool Function()? shouldYield,
    Duration timeout = const Duration(seconds: 5),
    void Function(Future<List<TrackCover>>)? onStuck,
    void Function(int, int)? onProgress,
  }) => runCoverPass(
    db: db,
    reader: reader,
    rootIds: [rootId],
    progress: progress,
    timeout: timeout,
    shouldYield: shouldYield ?? () => false,
    shouldStop: () => false,
    onStuck: onStuck ?? (_) {},
    onProgress: onProgress,
  );

  test('looks up every pending track in batches, then completes', () async {
    final files = names('n', 70);
    await add(files);
    for (final name in files) {
      reader.coverByName[name] = name;
    }
    var updates = 0;
    final sub = db
        .tableUpdates(TableUpdateQuery.onTable(db.tracks))
        .listen((_) => updates++);
    addTearDown(sub.cancel);

    final reports = <(int, int)>[];
    final result = await pass(onProgress: (d, t) => reports.add((d, t)));
    await pumpEventQueue();

    expect(reports, [(0, 70), (32, 70), (64, 70), (70, 70)]);
    expect(result.completed, isTrue);
    expect(reader.coverBatches.map((b) => b.length), [32, 32, 6]);
    expect((result.found, result.batches), (70, 3));
    expect(updates, 3, reason: 'one table update per batch');
    expect((await keys())['n69.mp3'], fakeCoverKey('n69.mp3'));
    expect(progress.cursor, isNull);
  });

  test('yields only after a batch, and resumes after the cursor', () async {
    await add(names('n', 40));
    final first = await pass(shouldYield: () => true);
    expect(first.completed, isFalse);
    expect(first.batches, 1);

    final second = await pass(shouldYield: () => true);
    expect(second.batches, 1);
    // Started past the top, so it wraps once: nothing is left there.
    expect(second.completed, isFalse);
    final third = await pass();
    expect(third.completed, isTrue);
    expect(reader.coverCount, 40, reason: 'no track looked up twice');
  });

  test('failing leading tracks never stop the rest', () async {
    final failing = names('a', 40);
    final good = names('b', 70);
    await add([...failing, ...good]);
    reader.failingCovers.addAll(failing);
    for (final name in good) {
      reader.coverByName[name] = name;
    }

    // A chain of passes that a follow-up scan always interrupts.
    var passes = 0;
    while (!(await pass(shouldYield: () => true)).completed) {
      passes++;
      expect(passes, lessThan(10));
    }
    final stored = await keys();
    expect(good.every((n) => stored[n] == fakeCoverKey(n)), isTrue);
    expect(progress.skipIds, hasLength(40));
    expect(
      reader.coverCount,
      110,
      reason: 'failed tracks are not tried again by follow-ups',
    );
  });

  test('scans the user asks for retry failures and still progress', () async {
    final failing = names('a', 40);
    final good = names('b', 70);
    await add([...failing, ...good]);
    reader.failingCovers.addAll(failing);

    // Each user scan clears the skip set and interrupts the pass again: the
    // failures are retried, and every pass still gets one batch further.
    var done = 0;
    for (var passes = 0; done < 70; passes++) {
      expect(passes, lessThan(10));
      progress.skipIds.clear();
      final result = await pass(shouldYield: () => true);
      expect(result.batches, 1);
      done += result.none;
    }
    expect((await keys()).length, 110);
  });

  test('a batch that hangs is skipped, the rest is done later', () async {
    final files = names('n', 40);
    await add(files);
    for (final name in files) {
      reader.coverByName[name] = name;
    }
    reader.hangingCovers.add('n00.mp3');
    Future<List<TrackCover>>? stuck;

    final first = await pass(
      timeout: const Duration(milliseconds: 30),
      onStuck: (pending) => stuck = pending,
    );
    expect(first.completed, isFalse);
    expect(stuck, isNotNull);
    expect(progress.skipIds, hasLength(32));

    reader.releaseHangingCovers();
    await stuck;
    final second = await pass();
    expect(second.completed, isTrue);
    expect(second.found, 8);
    expect((await keys())['n00.mp3'], isNull);
  });

  test('a malformed key is not stored and the track is skipped', () async {
    await add(['a.mp3']);
    final odd = _OddKeyReader();
    final result = await runCoverPass(
      db: db,
      reader: odd,
      rootIds: [rootId],
      progress: progress,
      timeout: const Duration(seconds: 5),
      shouldYield: () => false,
      shouldStop: () => false,
      onStuck: (_) {},
    );

    expect(result.failed, 1);
    expect((await keys())['a.mp3'], isNull);
    expect(progress.skipIds, hasLength(1));
  });

  test('progress counts only skipped tracks that still wait', () async {
    final files = names('n', 40);
    await add(files);
    final ids = [for (final row in await db.select(db.tracks).get()) row.id];
    // Five waiting tracks failed earlier, plus ids of tracks gone since.
    progress.skipIds.addAll([...ids.take(5), 9001, 9002, 9003, 9004]);
    for (final name in files) {
      reader.coverByName[name] = name;
    }

    final reports = <(int, int)>[];
    final result = await pass(onProgress: (d, t) => reports.add((d, t)));
    expect(reports, [(0, 35), (32, 35), (35, 35)]);
    expect(result.found, 35);
  });

  test('a batch that stores nothing announces nothing', () async {
    final files = names('n', 40);
    await add(files);
    reader.failingCovers.addAll(files.take(32));
    var updates = 0;
    final sub = db
        .tableUpdates(TableUpdateQuery.onTable(db.tracks))
        .listen((_) => updates++);
    addTearDown(sub.cancel);

    final result = await pass();
    await pumpEventQueue();
    expect((result.failed, result.none, result.batches), (32, 8, 2));
    expect(updates, 1, reason: 'only the batch that wrote rows');
  });

  test('reports nothing when no cover is waiting', () async {
    final reports = <(int, int)>[];
    final result = await pass(onProgress: (d, t) => reports.add((d, t)));
    expect(result.completed, isTrue);
    expect(reports, isEmpty);
  });

  test('stops before the first batch when the app is closing', () async {
    await add(['a.mp3']);
    final result = await runCoverPass(
      db: db,
      reader: reader,
      rootIds: [rootId],
      progress: progress,
      timeout: const Duration(seconds: 5),
      shouldYield: () => false,
      shouldStop: () => true,
      onStuck: (_) {},
    );
    expect(result.completed, isFalse);
    expect(reader.coverBatches, isEmpty);
  });
}

class _OddKeyReader extends FakeTagReader {
  @override
  Future<List<TrackCover>> readCovers(List<String> paths) async => [
    for (final path in paths)
      TrackCover(path: path, cover: 'not a key', status: CoverStatus.found),
  ];
}
