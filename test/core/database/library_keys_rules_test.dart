import 'dart:async';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_keys_provider.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/separator_rules.dart';
import 'package:kanaru/core/database/separator_rules_provider.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

const _pipe = SplitPrefs(separators: ['|'], keepWhole: []);
const _hash = SplitPrefs(separators: ['#'], keepWhole: []);

Future<void> _until(ProviderContainer c, bool Function() test) async {
  for (var i = 0; i < 500 && !test(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(test(), isTrue, reason: 'condition not reached');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
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

  void setArtistSplit(ProviderContainer c, SplitPrefs split) => c
      .read(settingsProvider.notifier)
      .setLibraryScan(
        c.read(settingsProvider).libraryScan.copyWith(artistSplit: split),
      );

  test('the settings give the rules the library is keyed with', () {
    final c = container((_, _, _) async {});
    expect(c.read(artistSplitRulesProvider), defaultArtistRules);
    expect(c.read(genreSplitRulesProvider), defaultGenreRules);
    setArtistSplit(c, _pipe);
    expect(
      c.read(artistSplitRulesProvider),
      const SplitRules(separators: ['|'], keepWhole: []),
    );
    expect(c.read(genreSplitRulesProvider), defaultGenreRules);
  });

  test('rules of a session are cleaned like the stored ones', () {
    final c = container((_, _, _) async {});
    setArtistSplit(
      c,
      SplitPrefs(
        separators: [' | ', 'a\u0000b', '|', 'x' * 65],
        keepWhole: const [],
      ),
    );
    expect(
      c.read(artistSplitRulesProvider),
      const SplitRules(separators: ['|', 'ab'], keepWhole: []),
    );
    setArtistSplit(
      c,
      SplitPrefs(
        separators: [for (var i = 0; i < 200; i++) 's$i'],
        keepWhole: const [],
      ),
    );
    expect(
      c.read(artistSplitRulesProvider),
      SplitRules(
        separators: [for (var i = 0; i < maxSplitEntries; i++) 's$i'],
        keepWhole: const [],
      ),
    );
  });

  test('changing the rules shows the updating state, then ready', () async {
    final seenRules = <SplitRules>[];
    final gate = Completer<void>();
    final c = container((_, rules, onProgress) async {
      seenRules.add(rules);
      if (seenRules.length == 1) return;
      onProgress(1, 4);
      await gate.future;
      onProgress(4, 4);
    });
    c.read(libraryKeysProvider);
    await _until(c, () => c.read(keysReadyProvider));

    final phases = <KeysPhase>[];
    c.listen(libraryKeysProvider, (_, s) => phases.add(s.phase));
    setArtistSplit(c, _pipe);
    await _until(c, () => c.read(keysUpdatingProvider));
    expect(c.read(libraryKeysProvider).done, 1);
    expect(c.read(libraryKeysProvider).total, 4);
    expect(c.read(keysReadyProvider), isFalse);

    gate.complete();
    await _until(c, () => c.read(keysReadyProvider));
    expect(phases.first, KeysPhase.updating);
    expect(phases.last, KeysPhase.ready);
    expect(seenRules, [
      defaultArtistRules,
      const SplitRules(separators: ['|'], keepWhole: []),
    ]);
  });

  test('a change that does not behave differently starts nothing', () async {
    var runs = 0;
    final c = container((_, _, _) async => runs++);
    c.read(libraryKeysProvider);
    await _until(c, () => c.read(keysReadyProvider));
    setArtistSplit(
      c,
      SplitPrefs(
        separators: defaultArtistSeparators.reversed.toList(),
        keepWhole: ['ac/dc'],
      ),
    );
    await pumpEventQueue();
    expect(runs, 1);
  });

  test('a change during a run runs again with the new rules', () async {
    final seenRules = <SplitRules>[];
    final gate = Completer<void>();
    final c = container((_, rules, _) async {
      seenRules.add(rules);
      if (seenRules.length == 1) await gate.future;
    });
    c.read(libraryKeysProvider);
    await _until(c, () => seenRules.length == 1);

    setArtistSplit(c, _pipe);
    await pumpEventQueue();
    expect(seenRules.length, 1, reason: 'one run at a time');
    setArtistSplit(c, _hash);
    gate.complete();

    await _until(c, () => seenRules.length == 2);
    await _until(c, () => c.read(keysReadyProvider));
    expect(seenRules.last, const SplitRules(separators: ['#'], keepWhole: []));
    await pumpEventQueue();
    expect(seenRules.length, 2, reason: 'the intermediate rules are skipped');
  });

  test(
    'a change during a quiet run is followed by a run with progress',
    () async {
      final seenRules = <SplitRules>[];
      final gate = Completer<void>();
      final c = container((_, rules, onProgress) async {
        seenRules.add(rules);
        if (seenRules.length == 2) {
          await gate.future;
        }
        if (seenRules.length == 3) onProgress(1, 2);
      });
      c.read(libraryKeysProvider);
      await _until(c, () => c.read(keysReadyProvider));
      // A scan leaves a row unkeyed: the quiet run starts and waits.
      await db.addRoots(['/m'], now: 1);
      await db.upsertTracks([
        TracksCompanion.insert(
          rootId: 1,
          path: '/m/1.flac',
          mtimeMs: 1,
          sizeBytes: 1,
          title: 'T',
          artist: const Value('A|B'),
          addedAt: 1,
          updatedAt: 1,
        ),
      ]);
      await db.customStatement('UPDATE tracks SET keys_version = 0');
      final quiet = c.read(libraryKeysProvider.notifier).keyStaleRows();
      await _until(c, () => seenRules.length == 2);
      expect(
        c.read(keysReadyProvider),
        isTrue,
        reason: 'the lists keep showing',
      );

      setArtistSplit(c, _pipe);
      gate.complete();
      await quiet;
      await _until(c, () => seenRules.length == 3);
      await _until(c, () => c.read(keysReadyProvider));
      expect(
        seenRules.last,
        const SplitRules(separators: ['|'], keepWhole: []),
      );
    },
  );

  test('rows a scan left unkeyed during a run are keyed after it', () async {
    var runs = 0;
    final gate = Completer<void>();
    final c = container((_, _, onProgress) async {
      if (++runs == 1) await gate.future;
    });
    c.read(libraryKeysProvider);
    await _until(c, () => runs == 1);

    final notifier = c.read(libraryKeysProvider.notifier);
    await notifier.keyStaleRows();
    expect(runs, 1, reason: 'not while a run is going');
    gate.complete();

    await _until(c, () => runs == 2);
    await _until(c, () => c.read(keysReadyProvider));
    await pumpEventQueue();
    expect(runs, 2, reason: 'one extra pass, then it settles');
  });

  test('the real backfill re-keys the library for the new rules', () async {
    await db.addRoots(['/m'], now: 1);
    await db.upsertTracks([
      for (var i = 1; i <= 3; i++)
        TracksCompanion.insert(
          rootId: 1,
          path: '/m/$i.flac',
          mtimeMs: 1,
          sizeBytes: 1,
          title: 'T$i',
          artist: const Value('A|B; C'),
          addedAt: 1,
          updatedAt: 1,
        ),
    ]);
    final c = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(db),
        libraryKeysRetryDelayProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(c.dispose);
    c.read(libraryKeysProvider);
    await _until(c, () => c.read(keysReadyProvider));
    Future<List<String>> artists() async => [
      for (final r
          in await db
              .customSelect(
                'SELECT artist_name AS n FROM track_artists '
                'WHERE track_id = 1 ORDER BY rowid',
              )
              .get())
        r.read<String>('n'),
    ];
    expect(await artists(), ['A|B', 'C']);
    final phases = <KeysPhase>[];
    c.listen(libraryKeysProvider, (_, s) => phases.add(s.phase));

    setArtistSplit(c, _pipe);
    await _until(c, () => phases.contains(KeysPhase.updating));
    await _until(c, () => c.read(keysReadyProvider));
    expect(await artists(), ['A', 'B; C']);

    phases.clear();
    setArtistSplit(c, defaultArtistSplit);
    await _until(c, () => phases.contains(KeysPhase.updating));
    await _until(c, () => c.read(keysReadyProvider));
    expect(await artists(), ['A|B', 'C']);
    final versions = await db
        .customSelect('SELECT DISTINCT keys_version AS v FROM tracks')
        .get();
    expect(
      [for (final r in versions) r.read<int>('v')],
      [keysVersionFor(defaultArtistRules)],
    );
  });
}
