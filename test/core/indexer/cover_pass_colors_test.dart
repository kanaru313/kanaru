import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/cover_colors/cover_color_extractor.dart';
import 'package:kanaru/core/database/cover_color_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/indexer/cover_pass.dart';
import 'package:kanaru/core/indexer/tag_reader.dart';

import '../cover_colors/fake_cover_color_extractor.dart';
import 'fake_tag_reader.dart';

void main() {
  late Directory tmp;
  late LibraryDatabase db;
  late FakeTagReader reader;
  late FakeCoverColorExtractor colors;
  late int rootId;
  late CoverPassProgress progress;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('cover_pass_colors_test');
    db = LibraryDatabase(NativeDatabase.memory());
    reader = FakeTagReader()..coverDirectory = '${tmp.path}/covers';
    colors = FakeCoverColorExtractor();
    rootId = (await db.addRoots(['/m'], now: 1)).single;
    progress = CoverPassProgress();
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  /// Stores [count] tracks `/m/nNN.mp3`, each with its own cover.
  Future<List<String>> addWithCovers(int count, {String prefix = 'n'}) async {
    final files = [
      for (var i = 0; i < count; i++)
        '$prefix${i.toString().padLeft(2, '0')}.mp3',
    ];
    await db.upsertTracks([
      for (final name in files)
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
    for (final name in files) {
      reader.coverByName[name] = name;
    }
    return [for (final name in files) fakeCoverKey(name)];
  }

  Future<CoverPassResult> pass({
    CoverColorExtractor? extractor,
    bool Function()? wanted,
    bool Function()? shouldYield,
    Duration timeout = const Duration(seconds: 5),
    void Function(Future<List<TrackCover>>)? onStuck,
  }) => runCoverPass(
    db: db,
    reader: reader,
    rootIds: [rootId],
    progress: progress,
    timeout: timeout,
    shouldYield: shouldYield ?? () => false,
    shouldStop: () => false,
    onStuck: onStuck ?? (_) {},
    colorExtractor: extractor,
    shouldExtractColors: wanted,
  );

  Future<int> storedColors() async =>
      (await db.select(db.coverColors).get()).length;

  test('without an extractor no colors are worked out', () async {
    await addWithCovers(3);
    final result = await pass(wanted: () => true);
    expect(result.completed, isTrue);
    expect(await storedColors(), 0);
  });

  test('with colors off the extractor is never called', () async {
    await addWithCovers(3);
    final result = await pass(extractor: colors, wanted: () => false);
    expect(result.completed, isTrue);
    expect(colors.calls, isEmpty);
    expect(await storedColors(), 0);
  });

  test(
    'with colors on every cover gets colors, in background batches',
    () async {
      final keys = await addWithCovers(70);
      final result = await pass(extractor: colors, wanted: () => true);
      expect(result.completed, isTrue);
      expect(colors.calls.map((c) => c.$1.length), [32, 32, 6]);
      expect(colors.calls.every((c) => c.$2), isTrue, reason: 'background');
      expect(result.colorsDone, 70);
      expect(await storedColors(), 70);
      expect(await db.coverKeysNeedingColors([rootId]), isEmpty);
      expect(await db.coverPaletteOf(keys.first), isNotNull);
    },
  );

  test('a later pass picks up covers stored before colors were on', () async {
    await addWithCovers(5);
    await pass(extractor: colors, wanted: () => false);
    expect(await storedColors(), 0);
    final result = await pass(extractor: colors, wanted: () => true);
    expect(result.colorsDone, 5);
    expect(await storedColors(), 5);
  });

  test(
    'stops for a waiting rescan; stores nothing once colors go off',
    () async {
      await addWithCovers(70);
      var yieldNow = false;
      colors.gate = null;
      final extractor = _AfterFirst(colors, () => yieldNow = true);
      final yielded = await pass(
        extractor: extractor,
        wanted: () => true,
        shouldYield: () => yieldNow,
      );
      expect(yielded.completed, isTrue);
      expect(yielded.colorsDone, 32);

      var on = true;
      final turnedOff = await pass(
        extractor: _AfterFirst(colors, () => on = false),
        wanted: () => on,
      );
      expect(turnedOff.colorsDone, 0, reason: 'answer came back after off');
      expect(await storedColors(), 32);
    },
  );

  test('an extractor error ends the round, not the pass', () async {
    await addWithCovers(3);
    colors.error = StateError('native gone');
    final result = await pass(extractor: colors, wanted: () => true);
    expect(result.completed, isTrue);
    expect(await storedColors(), 0);
  });

  test('a slow batch is skipped for the session without onStuck', () async {
    final keys = await addWithCovers(40);
    colors.gate = Completer<void>();
    var stuck = 0;
    final result = await pass(
      extractor: colors,
      wanted: () => true,
      timeout: const Duration(milliseconds: 50),
      onStuck: (_) => stuck++,
    );
    expect(result.completed, isTrue);
    expect(stuck, 0);
    expect(progress.skipColorKeys, keys.take(32).toSet());
    colors.gate!.complete();

    colors.gate = null;
    colors.calls.clear();
    final next = await pass(extractor: colors, wanted: () => true);
    expect(colors.calls.single.$1, keys.skip(32).toList());
    expect(next.colorsDone, 8);
  });

  test('failed covers are not stored and not tried again', () async {
    final keys = await addWithCovers(3);
    colors.colors[keys[1]] = null;
    final result = await pass(extractor: colors, wanted: () => true);
    expect((result.colorsDone, result.colorsFailed), (2, 1));
    expect(progress.skipColorKeys, {keys[1]});
    expect(await db.coverPaletteOf(keys[1]), isNull);

    colors.calls.clear();
    await pass(extractor: colors, wanted: () => true);
    expect(colors.calls, isEmpty);
  });

  test('no color round until the thumbnails are done', () async {
    await addWithCovers(40);
    final result = await pass(
      extractor: colors,
      wanted: () => true,
      shouldYield: () => true,
    );
    expect(result.completed, isFalse);
    expect(colors.calls, isEmpty);
  });
}

/// Passes calls to [inner] and runs [after] once the first call returns.
class _AfterFirst implements CoverColorExtractor {
  _AfterFirst(this.inner, this.after);

  final CoverColorExtractor inner;
  final void Function() after;
  var _calls = 0;

  @override
  Future<List<CoverColorSample>> extract(
    List<String> keys, {
    required bool background,
  }) async {
    final samples = await inner.extract(keys, background: background);
    if (++_calls == 1) after();
    return samples;
  }
}
