import 'dart:io';

import 'package:drift/drift.dart' show Variable;
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

  group('hidden folders and files', () {
    const showHidden = LibraryScanPrefs(skipHiddenFolders: false);

    test('by default a dot-file and a dot-folder stay out', () async {
      touch('.hidden/a.mp3');
      touch('._b.mp3');
      touch('c.mp3');

      await scan();

      expect(await stored(), {'c.mp3'});
    });

    test('with the option off a dot-folder is stored, trash is not', () async {
      touch('.hidden/a.mp3');
      touch('.Trash-1000/files/x.mp3');
      touch('.local/share/Trash/files/y.mp3');
      touch('.snapshots/1/z.mp3');
      touch('._b.mp3');
      configure(showHidden);

      await scan();

      expect(await stored(), {'.hidden/a.mp3'});
    });

    test('switching back on deletes the hidden folder rows', () async {
      touch('.hidden/a.mp3');
      touch('c.mp3');
      configure(showHidden);
      await scan();
      expect(await stored(), {'.hidden/a.mp3', 'c.mp3'});

      configure(const LibraryScanPrefs());
      await scan();

      expect(await stored(), {'c.mp3'});
      expect(summary().removed, 1);
    });

    test('a stored dot-file row is deleted by the next scan', () async {
      touch('x.mp3');
      await scan();
      await db.customStatement('UPDATE tracks SET path = ? WHERE path = ?', [
        '$root/._x.mp3',
        '$root/x.mp3',
      ]);
      expect(await stored(), {'._x.mp3'});

      await scan();

      expect(await stored(), {'x.mp3'});
      expect(summary().removed, 1);
    });

    test(
      'a root holding only hidden-folder rows is emptied, not kept',
      () async {
        touch('.hidden/a.mp3');
        configure(showHidden);
        await scan();
        expect(await stored(), {'.hidden/a.mp3'});

        configure(const LibraryScanPrefs());
        await scan();

        expect(await stored(), isEmpty);
        expect(summary().removed, 1);
        expect(summary().skippedRoots, isEmpty);
      },
    );

    test('a barred row does not let an empty walk delete the others', () async {
      touch('x.mp3');
      touch('y.mp3');
      await scan();
      await db.customStatement('UPDATE tracks SET path = ? WHERE path = ?', [
        '$root/._y.mp3',
        '$root/y.mp3',
      ]);
      File('$root/x.mp3').deleteSync();
      File('$root/y.mp3').deleteSync();

      await scan();

      expect(await stored(), {'x.mp3', '._y.mp3'});
    });

    test('a root with only a skipped dot-folder keeps its rows', () async {
      touch('a.mp3');
      await scan();
      File('$root/a.mp3').deleteSync();
      Directory('$root/.stfolder').createSync();

      await scan();

      expect(await stored(), {'a.mp3'}, reason: 'looks like a lost mount');
    });

    test('plays and favorites survive the deletion of the row', () async {
      final hidden = '$root/.hidden/a.mp3';
      touch('.hidden/a.mp3');
      configure(showHidden);
      await scan();
      await db.customStatement(
        'INSERT INTO plays (path, played_at) VALUES (?, 1)',
        [hidden],
      );
      await db.customStatement(
        "INSERT INTO playlists (name, created_at, kind) "
        "VALUES ('Favorites', 1, 'favorites')",
      );
      await db.customStatement(
        'INSERT INTO playlist_entries (playlist_id, path, position) '
        'SELECT id, ?, 0 FROM playlists',
        [hidden],
      );

      configure(const LibraryScanPrefs());
      await scan();

      expect(await stored(), isEmpty);
      for (final table in ['plays', 'play_stats', 'playlist_entries']) {
        final rows = await db
            .customSelect(
              'SELECT path FROM $table WHERE path = ?',
              variables: [Variable(hidden)],
            )
            .get();
        expect(rows, hasLength(1), reason: table);
      }
    });
  });
}
