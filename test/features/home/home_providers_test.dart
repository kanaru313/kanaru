import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/home_windows.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/play_history_writes.dart';
import 'package:kanaru/features/home/home_providers.dart';
import 'package:kanaru/shared/library_browse_refresh.dart';

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  final now = DateTime(2026, 10, 24, 12);
  late LibraryDatabase db;
  late ProviderContainer container;
  late int rootId;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    await db.addRoots(['/m'], now: 1);
    rootId = (await db.select(db.libraryRoots).getSingle()).id;
    container = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(db),
        libraryBrowseRefreshIntervalProvider.overrideWithValue(Duration.zero),
        homeClockProvider.overrideWithValue(() => now),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> track(String path, int addedAt) => db.upsertTracks([
    TracksCompanion.insert(
      rootId: rootId,
      path: path,
      mtimeMs: 1,
      sizeBytes: 1,
      title: 'T $path',
      artist: const Value('A'),
      addedAt: addedAt,
      updatedAt: 1,
    ),
  ]);

  int daysAgo(int days) =>
      DateTime(now.year, now.month, now.day - days, 11).millisecondsSinceEpoch;

  Future<HomeAddedWindow> effective() =>
      container.read(homeEffectiveAddedWindowProvider.future);

  group('default chip', () {
    test('an empty library shows all', () async {
      expect(await effective(), HomeAddedWindow.all);
    });

    for (final (days, expected) in [
      (0, HomeAddedWindow.day1),
      (5, HomeAddedWindow.day7),
      (40, HomeAddedWindow.all),
    ]) {
      test('newest track $days days old gives ${expected.slug}', () async {
        await track('/a', daysAgo(days));
        expect(await effective(), expected);
      });
    }
  });

  test('the picked chip outlives the providers that read it', () async {
    await track('/a', daysAgo(0));
    expect(await effective(), HomeAddedWindow.day1);

    container
        .read(homeAddedWindowChoiceProvider.notifier)
        .select(HomeAddedWindow.day30);
    expect(await effective(), HomeAddedWindow.day30);

    // No listener: every auto-disposed provider is gone after this.
    await _wait(20);
    expect(await effective(), HomeAddedWindow.day30);
    expect(
      container.read(homeAddedWindowChoiceProvider),
      HomeAddedWindow.day30,
    );
  });

  test('recently added follows the chip in effect', () async {
    await track('/new', daysAgo(0));
    await track('/old', daysAgo(10));
    final sub = container.listen(homeRecentlyAddedProvider, (_, _) {});
    addTearDown(sub.close);

    var rows = await container.read(homeRecentlyAddedProvider.future);
    expect([for (final r in rows) r.path], ['/new']);

    container
        .read(homeAddedWindowChoiceProvider.notifier)
        .select(HomeAddedWindow.day30);
    rows = await container.read(homeRecentlyAddedProvider.future);
    expect([for (final r in rows) r.path], ['/new', '/old']);
  });

  test(
    'a section reads again after a play and not after a checkpoint',
    () async {
      await track('/a', daysAgo(0));
      final data = <List<String>>[];
      final sub = container.listen(homeRecentlyPlayedProvider, (_, next) {
        final v = next.value;
        if (v != null) data.add([for (final r in v) r.path]);
      }, fireImmediately: true);
      addTearDown(sub.close);
      await container.read(homeRecentlyPlayedProvider.future);
      await _wait(20);
      expect(data, [<String>[]]);

      final id = await db
          .into(db.plays)
          .insert(PlaysCompanion.insert(path: '/a', playedAt: 5));
      await _wait(450);
      expect(data.last, ['/a']);
      final reads = data.length;

      await db.setPlayListened(id, 30000);
      await _wait(450);
      expect(data.length, reads);
    },
  );

  test('without a library every section is empty', () async {
    final c = ProviderContainer(
      overrides: [libraryDatabaseProvider.overrideWithValue(null)],
    );
    addTearDown(c.dispose);
    expect(await c.read(homeHasTracksProvider.future), isFalse);
    expect(await c.read(homeRecentlyPlayedProvider.future), isEmpty);
    expect(await c.read(homeRecentlyAddedProvider.future), isEmpty);
    expect(await c.read(homeMemoriesProvider.future), isEmpty);
    expect(await c.read(homeRecentAlbumsProvider.future), isEmpty);
    expect(await c.read(homeRecentArtistsProvider.future), isEmpty);
  });
}
