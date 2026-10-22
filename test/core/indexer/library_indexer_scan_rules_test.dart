import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/indexer_state.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import '../database/songs_reference_query.dart';
import 'fake_tag_reader.dart';

void main() {
  late Directory tmp;
  late String root;
  late LibraryDatabase db;
  late FakeTagReader reader;
  late ProviderContainer container;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('indexer_rules_test');
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

  void configure(LibraryScanPrefs prefs) =>
      container.read(settingsProvider.notifier).setLibraryScan(prefs);

  Future<void> scan() => container.read(libraryIndexerProvider.notifier).scan();
  ScanSummary summary() =>
      (container.read(libraryIndexerProvider) as IndexerFinished).summary;
  Future<Set<String>> stored() async => {
    for (final t in await db.songs()) t.path.substring(root.length + 1),
  };
  Set<String> read() => {
    for (final p in reader.batches.expand((b) => b))
      p.substring(root.length + 1),
  };

  group('minimum length', () {
    const min = LibraryScanPrefs(minDurationSeconds: 10);

    test('a short track is not stored, counted or read again', () async {
      touch('long.mp3');
      touch('short.mp3');
      reader.durationByName['short.mp3'] = 5000;
      reader.durationByName['long.mp3'] = 60000;
      configure(min);

      await scan();

      expect(await stored(), {'long.mp3'});
      expect(summary().added, 1, reason: 'the short one was not written');
      expect(read(), {'long.mp3', 'short.mp3'});

      reader.reset();
      await scan();

      expect(read(), isEmpty, reason: 'the short file is remembered');
      expect(summary().added, 0);
      expect(await stored(), {'long.mp3'});
    });

    test(
      'raising the minimum removes stored tracks of unchanged files',
      () async {
        touch('a.mp3');
        reader.durationByName['a.mp3'] = 5000;
        await scan();
        expect(await stored(), {'a.mp3'});

        configure(min);
        reader.reset();
        await scan();

        expect(await stored(), isEmpty);
        expect(summary().removed, 1);
        expect(read(), isEmpty, reason: 'the stored duration was enough');
      },
    );

    test(
      'lowering the minimum to 0 reads the file again and stores it',
      () async {
        touch('short.mp3');
        reader.durationByName['short.mp3'] = 5000;
        configure(min);
        await scan();
        expect(await stored(), isEmpty);

        configure(const LibraryScanPrefs());
        reader.reset();
        await scan();

        expect(read(), {'short.mp3'});
        expect(await stored(), {'short.mp3'});
        expect(summary().added, 1);
      },
    );

    test('a file whose tags failed is stored', () async {
      touch('bad.mp3');
      configure(min);

      await scan();

      expect(await stored(), {'bad.mp3'});
      expect(summary().failedTags, 1);
    });

    test(
      'a changed file is read again even when remembered as short',
      () async {
        final file = touch('a.mp3');
        reader.durationByName['a.mp3'] = 5000;
        configure(min);
        await scan();

        file.writeAsStringSync('longer content');
        reader.durationByName['a.mp3'] = 90000;
        reader.reset();
        await scan();

        expect(read(), {'a.mp3'});
        expect(await stored(), {'a.mp3'});
      },
    );

    test('a stored track that changed into a short one is removed', () async {
      final file = touch('a.mp3');
      reader.durationByName['a.mp3'] = 90000;
      await scan();
      expect(await stored(), {'a.mp3'});

      configure(min);
      file.writeAsStringSync('now a short clip');
      reader.durationByName['a.mp3'] = 3000;
      await scan();

      expect(await stored(), isEmpty);
      expect(summary().removed, 1);
      expect(summary().updated, 0);
    });
  });

  group('folders and file size', () {
    test(
      'a folder with .nomedia drops its stored tracks, the root one does not',
      () async {
        touch('a.mp3');
        touch('quiet/b.mp3');
        touch('quiet/deep/c.mp3');
        await scan();
        expect(await stored(), hasLength(3));

        touch('quiet/.nomedia', '');
        touch('.nomedia', '');
        configure(const LibraryScanPrefs(respectNomedia: true));
        await scan();

        expect(await stored(), {'a.mp3'});
        expect(summary().removed, 2);
      },
    );

    test('.nomedia is ignored while the option is off', () async {
      touch('quiet/.nomedia', '');
      touch('quiet/b.mp3');

      await scan();

      expect(await stored(), {'quiet/b.mp3'});
    });

    test('rules that leave no file at all delete the whole root', () async {
      touch('quiet/a.mp3');
      touch('quiet/b.mp3');
      await scan();
      expect(await stored(), hasLength(2));

      touch('quiet/.nomedia', '');
      configure(const LibraryScanPrefs(respectNomedia: true));
      await scan();

      expect(await stored(), isEmpty);
      expect(summary().removed, 2);
      expect(summary().skippedRoots, isEmpty);
    });

    test('small files are not read and stored ones go', () async {
      touch('big.mp3', 'x' * 2048);
      touch('tiny.mp3', 'x');
      await scan();
      expect(await stored(), hasLength(2));

      configure(const LibraryScanPrefs(minFileSizeKb: 1));
      reader.reset();
      await scan();

      expect(await stored(), {'big.mp3'});
      expect(read(), isEmpty);
    });

    test(
      'a first scan under the size rule never reads the small file',
      () async {
        touch('big.mp3', 'x' * 2048);
        touch('tiny.mp3', 'x');
        configure(const LibraryScanPrefs(minFileSizeKb: 1));

        await scan();

        expect(read(), {'big.mp3'});
        expect(summary().added, 1);
      },
    );
  });
}
