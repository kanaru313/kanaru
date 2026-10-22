import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_keys_backfill.dart';
import 'package:kanaru/core/database/library_keys_provider.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/text_keys.dart';

Future<void> _insert(LibraryDatabase db, int n, {String? artist}) async {
  await db.addRoots(['/m'], now: 1);
  await db.upsertTracks([
    for (var i = 1; i <= n; i++)
      TracksCompanion.insert(
        rootId: 1,
        path: '/m/$i.flac',
        mtimeMs: 1,
        sizeBytes: 1,
        title: 'The Bài $i',
        artist: Value(artist ?? 'Ánh $i; Beyoncé / Beyoncé'),
        album: Value('Album ${i % 3}'),
        addedAt: 1,
        updatedAt: 1,
      ),
  ]);
  // A scan keys what it writes; these tests need a library as the previous
  // schema left it, with no keys and no credits.
  await db.customStatement(
    "UPDATE tracks SET keys_version = 0, title_sort = '', "
    'artist_sort = NULL, album_sort = NULL, album_artist_key = NULL, '
    'album_title_key = NULL, album_display_artist = NULL, '
    'artist_search = NULL, album_search = NULL, album_artist_search = NULL, '
    'genre_search = NULL',
  );
  await db.customStatement('DELETE FROM track_artists');
}

Future<List<int>> _versions(LibraryDatabase db) async => [
  for (final r
      in await db
          .customSelect('SELECT keys_version AS v FROM tracks ORDER BY id')
          .get())
    r.read<int>('v'),
];

Future<int> _credits(LibraryDatabase db) async =>
    (await db
            .customSelect('SELECT count(*) AS n FROM track_artists')
            .getSingle())
        .read<int>('n');

Future<void> _untilStatus(
  ProviderContainer c,
  bool Function(LibraryKeysStatus) test,
) {
  if (test(c.read(libraryKeysProvider))) return Future.value();
  final done = Completer<void>();
  final sub = c.listen(libraryKeysProvider, (_, s) {
    if (test(s) && !done.isCompleted) done.complete();
  });
  return done.future
      .timeout(const Duration(seconds: 20))
      .whenComplete(sub.close);
}

// The version the default run writes.
const v = textKeysVersion;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('keys every row in chunks and reports progress', () async {
    await _insert(db, 7);
    final progress = <(int, int)>[];
    final n = await backfillLibraryKeys(
      db,
      chunkSize: 3,
      onProgress: (done, total) => progress.add((done, total)),
    );
    expect(n, 7);
    expect(progress, [(0, 7), (3, 7), (6, 7), (7, 7)]);
    expect(await _versions(db), everyElement(textKeysVersion));
    // Two artists per track: the NFD and NFC Beyoncé are one.
    expect(await _credits(db), 14);
    final row = await (db.select(
      db.tracks,
    )..where((t) => t.id.equals(1))).getSingle();
    expect(row.titleSort, 'the bai 1');
    expect(row.artistSort, isNotNull);
    expect(row.albumSort, 'album 1');
    expect(row.albumTitleKey, 'album 1');
    expect(row.albumDisplayArtist, 'Ánh 1');
  });

  test('a second run finds nothing to do', () async {
    await _insert(db, 3);
    await backfillLibraryKeys(db);
    expect(await backfillLibraryKeys(db), 0);
  });

  test(
    'a higher version re-keys everything without duplicate credits',
    () async {
      await _insert(db, 4);
      await backfillLibraryKeys(db, version: 1);
      expect(await backfillLibraryKeys(db, version: 1), 0);
      expect(await backfillLibraryKeys(db, version: 2, chunkSize: 3), 4);
      expect(await _versions(db), everyElement(2));
      expect(await _credits(db), 8);
    },
  );

  test('a row the database refuses is skipped, the others are keyed', () async {
    await _insert(db, 5);
    await db.customStatement(
      'CREATE TRIGGER refuse BEFORE UPDATE ON tracks WHEN NEW.id = 3 '
      "BEGIN SELECT RAISE(ABORT, 'refused'); END",
    );
    await backfillLibraryKeys(db, chunkSize: 5);
    expect(await _versions(db), [v, v, 0, v, v]);
    // The refused track keeps its old (empty) credits.
    expect(await _credits(db), 8);
  });

  test(
    'a track changed between reading and writing is not given old keys',
    () async {
      await _insert(db, 3);
      await backfillLibraryKeys(
        db,
        afterRead: () => db.customStatement(
          "UPDATE tracks SET title = 'Changed', artist = 'New Artist' "
          'WHERE id = 2',
        ),
      );
      expect(await _versions(db), [v, 0, v]);
      final credits = await db
          .customSelect(
            'SELECT count(*) AS n FROM track_artists WHERE track_id = 2',
          )
          .getSingle();
      expect(credits.read<int>('n'), 0);
      // The next pass keys it from its new tags.
      expect(await backfillLibraryKeys(db), 1);
      final row = await (db.select(
        db.tracks,
      )..where((t) => t.id.equals(2))).getSingle();
      expect(row.titleSort, 'changed');
      expect(await _credits(db), 2 + 1 + 2);
    },
  );

  test(
    'a track deleted between reading and writing does not fail the chunk',
    () async {
      await _insert(db, 3);
      await backfillLibraryKeys(
        db,
        afterRead: () => db.customStatement('DELETE FROM tracks WHERE id = 2'),
      );
      expect(await _versions(db), [v, v]);
      expect(await _credits(db), 4);
    },
  );

  test('an interrupted run resumes after reopening the file', () async {
    final dir = Directory.systemTemp.createTempSync('kanaru_keys_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/library.db');

    var first = LibraryDatabase(NativeDatabase(file));
    await _insert(first, 9);
    await expectLater(
      backfillLibraryKeys(
        first,
        chunkSize: 4,
        onProgress: (done, _) {
          if (done == 4) throw StateError('app quit');
        },
      ),
      throwsStateError,
    );
    expect(await _versions(first), [v, v, v, v, 0, 0, 0, 0, 0]);
    await first.close();

    first = LibraryDatabase(NativeDatabase(file));
    addTearDown(first.close);
    expect(await backfillLibraryKeys(first, chunkSize: 4), 5);
    expect(await _versions(first), everyElement(textKeysVersion));
    expect(await _credits(first), 18);
  });

  group('status', () {
    ProviderContainer container({
      KeysBackfillRunner? runner,
      bool open = true,
    }) {
      final c = ProviderContainer(
        overrides: [
          libraryDatabaseProvider.overrideWithValue(open ? db : null),
          libraryKeysRetryDelayProvider.overrideWithValue(Duration.zero),
          if (runner != null)
            libraryKeysRunnerProvider.overrideWithValue(runner),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('is ready at once without a database', () {
      expect(container(open: false).read(keysReadyProvider), isTrue);
    });

    test('goes from ready to not ready to ready with progress', () async {
      await _insert(db, 5);
      final c = container();
      final seen = <LibraryKeysStatus>[];
      c.listen(libraryKeysProvider, (_, next) => seen.add(next));

      await _untilStatus(c, (s) => s.ready && s.done == 5);
      expect(seen.first.updating, isTrue);
      expect(seen.last.done, 5);
      expect(seen.last.total, 5);
      expect(seen.last.fraction, 1.0);
      expect(await _versions(db), everyElement(textKeysVersion));
    });

    test(
      'a backlog beyond the in-place limit is keyed on an isolate',
      () async {
        await _insert(db, keysInPlaceLimit + 100, artist: 'Solo');
        final seen = <(int, int)>[];
        await runKeysBackfillInBackground(db, (d, t) => seen.add((d, t)));
        expect(await _versions(db), everyElement(textKeysVersion));
        expect(seen.last, (keysInPlaceLimit + 100, keysInPlaceLimit + 100));
      },
    );

    test('a keyed library never shows the updating state', () async {
      await _insert(db, 3);
      await backfillLibraryKeys(db);
      final c = container();
      final seen = <KeysPhase>[];
      c.listen(libraryKeysProvider, (_, s) => seen.add(s.phase));
      // Not known yet: lists wait instead of reading unkeyed rows.
      expect(c.read(keysReadyProvider), isFalse);
      await _untilStatus(c, (s) => s.ready);
      expect(seen, [KeysPhase.ready]);
    });

    test('the lists wait while the count of stale rows is pending', () async {
      final count = Completer<void>();
      final c = container(
        runner: (_, _) async {
          await count.future;
        },
      );
      expect(c.read(libraryKeysProvider).phase, KeysPhase.unknown);
      expect(c.read(keysReadyProvider), isFalse);
      expect(c.read(keysUpdatingProvider), isFalse);
      await pumpEventQueue();
      expect(c.read(keysReadyProvider), isFalse);
      count.complete();
      await _untilStatus(c, (s) => s.ready);
    });

    test('the end of a run reaches listeners on this isolate', () async {
      final dir = Directory.systemTemp.createTempSync('kanaru_keys_notice');
      addTearDown(() => dir.deleteSync(recursive: true));
      final fileDb = LibraryDatabase(
        NativeDatabase.createInBackground(
          File('${dir.path}/library.db'),
          setup: applyLibraryPragmas,
        ),
      );
      addTearDown(fileDb.close);
      await _insert(fileDb, keysInPlaceLimit + 50, artist: 'Solo');
      final notices = <Set<TableUpdate>>[];
      final sub = fileDb.tableUpdates().listen(notices.add);
      addTearDown(sub.cancel);

      // No provider here: only the notices the run itself sends are seen.
      await runKeysBackfillInBackground(fileDb, (_, _) {});
      await pumpEventQueue();

      expect(await _versions(fileDb), everyElement(textKeysVersion));
      expect(
        notices.expand((n) => n).where((u) => u.table == 'tracks'),
        isNotEmpty,
      );
    });

    test('rows left unkeyed are keyed after a scan, quietly', () async {
      await _insert(db, 3);
      final c = container();
      c.read(libraryKeysProvider);
      await _untilStatus(c, (s) => s.ready);
      // A row the first run could not key: back to unkeyed.
      await db.customStatement('UPDATE tracks SET keys_version = 0');
      final seen = <KeysPhase>[];
      c.listen(libraryKeysProvider, (_, s) => seen.add(s.phase));

      await c.read(libraryKeysProvider.notifier).keyStaleRows();

      expect(await _versions(db), everyElement(textKeysVersion));
      expect(seen, isEmpty, reason: 'the lists keep showing');
    });

    test('keying after a scan does nothing when all rows are keyed', () async {
      var calls = 0;
      final c = container(
        runner: (_, _) async {
          calls++;
        },
      );
      await _untilStatus(c, (s) => s.ready);
      await c.read(libraryKeysProvider.notifier).keyStaleRows();
      expect(calls, 1, reason: 'only the first run');
    });

    test('a failing run is retried, then lets the lists show', () async {
      var calls = 0;
      final c = container(
        runner: (_, _) {
          calls++;
          throw StateError('disk full');
        },
      );
      c.read(keysReadyProvider);
      for (var i = 0; i < 200 && calls < keysAttempts; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await pumpEventQueue();
      expect(calls, keysAttempts);
      expect(c.read(keysReadyProvider), isTrue);
    });

    test('a run that fails once then works keys the library', () async {
      await _insert(db, 3);
      var calls = 0;
      final c = container(
        runner: (db, onProgress) {
          if (++calls == 1) throw StateError('locked');
          return backfillLibraryKeys(db, onProgress: onProgress);
        },
      );
      c.read(keysReadyProvider);
      await _untilStatus(c, (s) => s.ready && s.done == 3);
      expect(calls, 2);
      expect(await _versions(db), everyElement(textKeysVersion));
    });

    test('progress never exceeds the total', () async {
      final c = container(
        runner: (_, onProgress) async {
          onProgress(0, 4);
          onProgress(6, 4);
        },
      );
      final seen = <LibraryKeysStatus>[];
      c.listen(libraryKeysProvider, (_, s) => seen.add(s));
      await _untilStatus(c, (s) => s.ready && s.total == 4);
      expect(seen.every((s) => s.done <= s.total), isTrue);
    });
  });
}
