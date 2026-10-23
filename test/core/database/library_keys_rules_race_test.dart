import 'package:drift/drift.dart' show Value, Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_keys_backfill.dart';
import 'package:kanaru/core/database/library_keys_provider.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/separator_rules.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

const _hash = SplitPrefs(separators: ['#'], keepWhole: []);
const _hashRules = SplitRules(separators: ['#'], keepWhole: []);

TracksCompanion _track(int i) => TracksCompanion.insert(
  rootId: 1,
  path: '/m/$i.flac',
  mtimeMs: 1,
  sizeBytes: 1,
  title: 'Song $i',
  artist: Value('Left $i # Right $i'),
  addedAt: 1,
  updatedAt: 1,
);

Future<void> _until(bool Function() test) async {
  for (var i = 0; i < 1000 && !test(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(test(), isTrue, reason: 'condition not reached');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('rules changed and a row scanned under them while an older run is '
      'writing end with every row keyed by the new rules', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addRoots(['/m'], now: 1);
    // Rows left by an older version: stale under any rules.
    await db.upsertTracks([for (var i = 1; i <= 3; i++) _track(i)]);
    await db.customStatement('UPDATE tracks SET keys_version = 0');

    late ProviderContainer c;
    var firstChunk = true;
    var runs = 0;
    Future<void> runner(
      LibraryDatabase db,
      SplitRules rules,
      void Function(int, int) onProgress,
    ) async {
      runs++;
      await backfillLibraryKeys(
        db,
        rules: rules,
        chunkSize: 1,
        onProgress: onProgress,
        afterRead: () async {
          if (!firstChunk || rules == _hashRules) return;
          firstChunk = false;
          // Between reading and writing the first chunk: the rules change,
          // and a scan writes a new row with the new rules.
          c
              .read(settingsProvider.notifier)
              .setLibraryScan(
                c
                    .read(settingsProvider)
                    .libraryScan
                    .copyWith(artistSplit: _hash),
              );
          await db.upsertTracks([_track(4)], artistRules: _hashRules);
        },
      );
    }

    c = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(db),
        libraryKeysRetryDelayProvider.overrideWithValue(Duration.zero),
        libraryKeysRunnerProvider.overrideWithValue(runner),
      ],
    );
    addTearDown(c.dispose);
    c.read(libraryKeysProvider);
    await _until(() => runs >= 2 && c.read(keysReadyProvider));

    final versions = {
      for (final r
          in await db
              .customSelect('SELECT keys_version AS v FROM tracks')
              .get())
        r.read<int>('v'),
    };
    expect(versions, {keysVersionFor(_hashRules)});
    for (var id = 1; id <= 4; id++) {
      final names = [
        for (final r
            in await db
                .customSelect(
                  'SELECT artist_name FROM track_artists '
                  'WHERE track_id = ? ORDER BY artist_name',
                  variables: [Variable.withInt(id)],
                )
                .get())
          r.read<String>('artist_name'),
      ];
      expect(names, ['Left $id', 'Right $id'], reason: 'track $id');
    }
  });
}
