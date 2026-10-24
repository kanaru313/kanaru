import 'dart:async';
import 'dart:isolate';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/album_grouping_keys.dart';
import 'package:kanaru/core/database/album_grouping_provider.dart';
import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_keys_backfill.dart';
import 'package:kanaru/core/database/library_keys_provider.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/separator_rules.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

const _noArtist = AlbumGrouping(byAlbumArtist: false);

Future<void> _until(bool Function() test) async {
  for (var i = 0; i < 500 && !test(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(test(), isTrue, reason: 'condition not reached');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late LibraryDatabase db;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    await db.addRoots(['/m'], now: 1);
    await db.upsertTracks([
      for (var i = 1; i <= 2; i++)
        TracksCompanion.insert(
          rootId: 1,
          path: '/m/$i.flac',
          mtimeMs: 1,
          sizeBytes: 1,
          title: 'T$i',
          artist: Value('Artist $i'),
          album: const Value('Album'),
          albumArtist: Value('Artist $i'),
          addedAt: 1,
          updatedAt: 1,
        ),
    ]);
  });
  tearDown(() => db.close());

  ProviderContainer container(KeysBackfillRunner runner) {
    final c = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(db),
        libraryKeysRetryDelayProvider.overrideWithValue(Duration.zero),
        libraryKeysRunnerProvider.overrideWithValue(runner),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  void setGrouping(ProviderContainer c, AlbumGrouping g) => c
      .read(settingsProvider.notifier)
      .setLibraryScan(
        c.read(settingsProvider).libraryScan.copyWith(albumGrouping: g),
      );

  test('the settings give the grouping', () {
    final c = container((_, _, _) async {});
    expect(c.read(albumGroupingProvider), const AlbumGrouping());
    setGrouping(c, _noArtist);
    expect(c.read(albumGroupingProvider), _noArtist);
  });

  test('changing the grouping re-keys with progress and ends ready', () async {
    final seen = <AlbumGrouping>[];
    final gate = Completer<void>();
    final c = container((db, rules, onProgress) async {
      final grouping = albumGroupingFor(db);
      seen.add(grouping);
      if (seen.length == 1) return;
      onProgress(1, 2);
      await gate.future;
      await backfillLibraryKeys(db, rules: rules, grouping: grouping);
      onProgress(2, 2);
    });
    c.read(libraryKeysProvider);
    await _until(() => c.read(keysReadyProvider));
    expect(albumGroupingFor(db), const AlbumGrouping());

    setGrouping(c, _noArtist);
    // Reading the provider flushes the change to its listeners.
    expect(c.read(albumGroupingProvider), _noArtist);
    // The listener sets the registry at once, before the run it asks for.
    expect(albumGroupingFor(db), _noArtist);
    await _until(() => c.read(keysUpdatingProvider));
    expect(c.read(libraryKeysProvider).total, 2);
    gate.complete();
    await _until(() => c.read(keysReadyProvider));
    expect(seen, [const AlbumGrouping(), _noArtist]);

    expect(await db.albums(), hasLength(1));
    expect(
      await countStaleKeys(db, keysVersionFor(defaultArtistRules, _noArtist)),
      0,
    );
  });

  test('a grouping set before the first run is used by it', () async {
    final seen = <AlbumGrouping>[];
    final c = container((db, _, _) async => seen.add(albumGroupingFor(db)));
    setGrouping(c, _noArtist);
    c.read(libraryKeysProvider);
    await _until(() => c.read(keysReadyProvider));
    expect(seen, [_noArtist]);
  });

  test('keyStaleRows counts against the grouping', () async {
    var runs = 0;
    final c = container((_, _, _) async => runs++);
    c.read(libraryKeysProvider);
    await _until(() => c.read(keysReadyProvider));
    expect(runs, 1);
    // Rows carry the default version; the registry still says default.
    await c.read(libraryKeysProvider.notifier).keyStaleRows();
    expect(runs, 1);
    setGrouping(c, _noArtist);
    expect(c.read(albumGroupingProvider), _noArtist);
    await _until(() => runs == 2);
    // The fake runner keyed nothing, so the rows are still stale.
    await _until(() => c.read(keysReadyProvider));
    await c.read(libraryKeysProvider.notifier).keyStaleRows();
    expect(runs, 3);
  });

  test('the real runner keys with the registered grouping', () async {
    final c = container(runKeysBackfillInBackground);
    c.read(libraryKeysProvider);
    await _until(() => c.read(keysReadyProvider));
    setGrouping(c, _noArtist);
    expect(c.read(albumGroupingProvider), _noArtist);
    expect(albumGroupingFor(db), _noArtist);
    for (var i = 0; i < 500; i++) {
      if (await countStaleKeys(
            db,
            keysVersionFor(defaultArtistRules, _noArtist),
          ) ==
          0) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(await db.albums(), hasLength(1));
  });

  test('a grouping changed during a run gets a second pass with it', () async {
    final gate = Completer<void>();
    final groupings = <AlbumGrouping>[];
    var first = true;
    final c = container((db, rules, onProgress) async {
      final grouping = albumGroupingFor(db);
      groupings.add(grouping);
      await backfillLibraryKeys(
        db,
        rules: rules,
        grouping: grouping,
        chunkSize: 1,
        onProgress: onProgress,
        afterRead: () async {
          if (!first) return;
          first = false;
          await gate.future;
        },
      );
    });
    c.read(libraryKeysProvider);
    // The default-keyed rows are current; make them stale so run 1 writes.
    await db.customStatement('UPDATE tracks SET keys_version = 0');
    await _until(() => !first);

    setGrouping(c, _noArtist);
    expect(c.read(albumGroupingProvider), _noArtist);
    gate.complete();
    await _until(() => groupings.length >= 2 && c.read(keysReadyProvider));
    expect(groupings.last, _noArtist);
    expect(
      await countStaleKeys(db, keysVersionFor(defaultArtistRules, _noArtist)),
      0,
    );
    expect(await db.albums(), hasLength(1));
  });

  test('the isolate computation keys with the grouping it was given', () async {
    // This database has no registered grouping, like the isolate's.
    expect(albumGroupingFor(db), const AlbumGrouping());
    final port = ReceivePort();
    addTearDown(port.close);
    await isolateKeysComputation(port.sendPort, defaultArtistRules, _noArtist)(
      db,
    );
    expect(await db.albums(), hasLength(1));
    expect(
      await countStaleKeys(db, keysVersionFor(defaultArtistRules, _noArtist)),
      0,
    );
  });
}
