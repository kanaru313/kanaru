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

  group('data safety', () {
    final fixedMtime = DateTime.fromMillisecondsSinceEpoch(1700000000000);

    test(
      'a reader failure on batch 2 keeps batch 1 and deletes nothing',
      () async {
        for (var i = 0; i < 600; i++) {
          touch('t$i.mp3', '');
        }
        await scan();
        expect(await tracks(), hasLength(600));

        // Everything changed, one file is gone, and the reader dies on batch 2.
        File('$root/t0.mp3').deleteSync();
        for (var i = 1; i < 600; i++) {
          File('$root/t$i.mp3').setLastModifiedSync(fixedMtime);
        }
        reader
          ..reset()
          ..failOnBatch = 2;
        await scan();

        expect(state(), isA<IndexerFailed>());
        final rows = await db.select(db.tracks).get();
        expect(rows, hasLength(600), reason: 'the vanished row survives');
        expect(
          rows.where((r) => r.mtimeMs == fixedMtime.millisecondsSinceEpoch),
          hasLength(512),
          reason: 'batch 1 stays written',
        );

        // The next scan finishes the job.
        reader.reset();
        await scan();
        expect(summary().removed, 1);
        expect(await tracks(), hasLength(599));
      },
    );

    test(
      'an unreadable subfolder keeps its rows',
      () async {
        touch('a.mp3');
        touch('locked/x.mp3');
        await scan();

        Process.runSync('chmod', ['000', '$root/locked']);
        addTearDown(() => Process.runSync('chmod', ['755', '$root/locked']));
        await scan();

        expect(summary().removed, 0);
        expect(await tracks(), hasLength(2));
      },
      skip: Process.runSync('id', ['-u']).stdout.toString().trim() == '0'
          ? 'root can read everything'
          : false,
    );

    test('an emptied subfolder (unmounted drive) keeps its rows', () async {
      touch('a.mp3');
      final x = touch('nas/x.mp3');
      await scan();

      x.deleteSync();
      await scan();

      expect(summary().removed, 0);
      expect(await tracks(), hasLength(2));
    });

    test('a link whose target vanished keeps its row', () async {
      touch('a.mp3');
      final target = touch('store/t.dat');
      Link('$root/link.mp3').createSync(target.path);
      await scan();
      expect(await tracks(), hasLength(2));

      target.deleteSync();
      await scan();

      expect(summary().removed, 0);
      expect(await tracks(), hasLength(2));
    });
  });
}
