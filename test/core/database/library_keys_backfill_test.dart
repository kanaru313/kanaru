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
    expect(await _versions(db), [1, 1, 0, 1, 1]);
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
      expect(await _versions(db), [1, 0, 1]);
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
      expect(await _versions(db), [1, 1]);
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
    expect(await _versions(first), [1, 1, 1, 1, 0, 0, 0, 0, 0]);
    await first.close();

    first = LibraryDatabase(NativeDatabase(file));
    addTearDown(first.close);
    expect(await backfillLibraryKeys(first, chunkSize: 4), 5);
    expect(await _versions(first), everyElement(1));
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
      expect(seen.first.ready, isFalse);
      expect(seen.last.done, 5);
      expect(seen.last.total, 5);
      expect(seen.last.fraction, 1.0);
      expect(await _versions(db), everyElement(1));
    });

    test(
      'a backlog beyond the in-place limit is keyed on an isolate',
      () async {
        await _insert(db, keysInPlaceLimit + 100, artist: 'Solo');
        final seen = <(int, int)>[];
        await runKeysBackfillInBackground(db, (d, t) => seen.add((d, t)));
        expect(await _versions(db), everyElement(1));
        expect(seen.last, (keysInPlaceLimit + 100, keysInPlaceLimit + 100));
      },
    );

    test('a keyed library never shows the updating state', () async {
      await _insert(db, 3);
      await backfillLibraryKeys(db);
      final c = container();
      final seen = <bool>[];
      c.listen(keysReadyProvider, (_, ready) => seen.add(ready));
      expect(c.read(keysReadyProvider), isTrue);
      await pumpEventQueue();
      expect(seen, isEmpty);
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
      expect(await _versions(db), everyElement(1));
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
