import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/indexer_state.dart';

import 'fake_tag_reader.dart';

void main() {
  late Directory tmp;
  late String root;
  late LibraryDatabase db;
  late FakeTagReader reader;
  late ProviderContainer container;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('indexer_test');
    root = '${tmp.resolveSymbolicLinksSync()}/music';
    Directory(root).createSync();
    db = LibraryDatabase(NativeDatabase.memory());
    reader = FakeTagReader();
    container = ProviderContainer(
      overrides: [
        ...LibraryStartup(db: db).overrides,
        tagReaderProvider.overrideWithValue(reader),
      ],
    );
    await db.addRoots([root], now: 1);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  File touch(String rel, [String content = 'x']) => File('$root/$rel')
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  Future<void> scan() => container.read(libraryIndexerProvider.notifier).scan();
  IndexerState state() => container.read(libraryIndexerProvider);
  ScanSummary summary() => (state() as IndexerFinished).summary;
  Future<List<TrackListItem>> tracks() => db.watchTrackListItems().first;

  Future<int> idOf(String rel) async =>
      (await tracks()).firstWhere((t) => t.path == '$root/$rel').id;

  test('first scan stores every file; second reads only failed ones', () async {
    touch('a.mp3');
    touch('sub/b.flac');
    touch('bad.mp3');

    await scan();

    expect(summary().added, 3);
    expect(summary().failedTags, 1);
    expect(reader.readCount, 3);
    final stored = await tracks();
    expect(stored.map((t) => t.title), containsAll(['A.MP3', 'B.FLAC', 'bad']));
    expect((await db.roots()).single.lastScanAt, isNotNull);

    reader.reset();
    await scan();

    expect(reader.batches.expand((b) => b), [
      '$root/bad.mp3',
    ], reason: 'a failed read is retried, unchanged files are not');
    expect(summary().added, 0);
    expect(summary().updated, 0);
    expect(summary().failedTags, 1);
    expect((await tracks()), hasLength(3));
  });

  test('a changed file is read again and keeps id and addedAt', () async {
    final a = touch('a.mp3');
    touch('b.mp3');
    await scan();
    final id = await idOf('a.mp3');
    final before = await (db.select(
      db.tracks,
    )..where((t) => t.id.equals(id))).getSingle();

    a.setLastModifiedSync(DateTime.now().add(const Duration(hours: 1)));
    reader.reset();
    await scan();

    expect(reader.batches.expand((b) => b), ['$root/a.mp3']);
    expect(summary().updated, 1);
    final after = await (db.select(
      db.tracks,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(after.id, id);
    expect(after.addedAt, before.addedAt);
    expect(after.mtimeMs, isNot(before.mtimeMs));
  });

  test('a deleted file loses its row', () async {
    touch('a.mp3');
    final b = touch('b.mp3');
    await scan();

    b.deleteSync();
    await scan();

    expect(summary().removed, 1);
    expect((await tracks()).map((t) => t.path), ['$root/a.mp3']);
  });

  test('a missing root keeps its rows and is reported', () async {
    touch('a.mp3');
    await scan();

    Directory(root).deleteSync(recursive: true);
    await scan();

    expect(summary().skippedRoots, {root: SkipReason.missing});
    expect(await tracks(), hasLength(1));
  });

  test('an emptied root keeps its rows and is reported', () async {
    final a = touch('a.mp3');
    await scan();

    a.deleteSync();
    await scan();

    expect(summary().skippedRoots, {root: SkipReason.empty});
    expect(summary().removed, 0);
    expect(await tracks(), hasLength(1));
  });

  test('a reader failure ends in failed, and the next scan works', () async {
    touch('a.mp3');
    reader.throwOnRead = StateError('native library missing');

    await scan();

    expect(state(), isA<IndexerFailed>());
    expect((state() as IndexerFailed).message, contains('native library'));

    reader.throwOnRead = null;
    await scan();

    expect(state(), isA<IndexerFinished>());
    expect(await tracks(), hasLength(1));
  });

  test('two scan() calls in a row run once', () async {
    touch('a.mp3');
    final notifier = container.read(libraryIndexerProvider.notifier);

    final first = notifier.scan();
    final second = notifier.scan();
    expect(identical(first, second), isTrue);
    await Future.wait([first, second]);

    expect(reader.batches, hasLength(1));
  });

  test('reads in sequential batches of at most 512', () async {
    for (var i = 0; i < 520; i++) {
      touch('t$i.mp3', '');
    }

    await scan();

    expect(reader.batches.map((b) => b.length).toList()..sort(), [8, 512]);
    expect(await tracks(), hasLength(520));
  });

  test('without a database it does nothing', () async {
    final bare = ProviderContainer(
      overrides: [tagReaderProvider.overrideWithValue(reader)],
    );
    addTearDown(bare.dispose);

    await bare.read(libraryIndexerProvider.notifier).scan();

    expect(bare.read(libraryIndexerProvider), isA<IndexerIdle>());
    expect(reader.batches, isEmpty);
  });

  test('a scan requested while scanning runs one more pass', () async {
    touch('a.mp3');
    final notifier = container.read(libraryIndexerProvider.notifier);

    final first = notifier.scan();
    // A root added mid-scan is not in the roots the running pass read.
    final other = Directory('${tmp.resolveSymbolicLinksSync()}/other')
      ..createSync();
    File('${other.path}/b.mp3').writeAsStringSync('x');
    await db.addRoots([other.path], now: 2);
    final second = notifier.scan();
    await Future.wait([first, second]);

    expect((await tracks()).map((t) => t.path).toSet(), {
      '$root/a.mp3',
      '${other.path}/b.mp3',
    });
    expect(state(), isA<IndexerFinished>());
  });

  test('finished and failed states carry the time they ended', () async {
    touch('a.mp3');
    final before = DateTime.now();
    await scan();
    final at = (state() as IndexerFinished).at;
    expect(at.isBefore(before), isFalse);

    reader.throwOnRead = StateError('x');
    touch('c.mp3');
    await scan();
    expect((state() as IndexerFailed).at.isBefore(at), isFalse);
  });
}
