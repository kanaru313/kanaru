import 'package:drift/drift.dart' show TableUpdate, UpdateKind;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/play_history_writes.dart';
import 'package:kanaru/features/home/home_data_version.dart';
import 'package:kanaru/shared/library_browse_refresh.dart';

/// A fixed local time, so the day is the same at any hour the suite runs.
final _noon = DateTime(2026, 10, 24, 12);

void main() {
  late LibraryDatabase db;
  late ProviderContainer container;
  late List<int> seen;
  var clockNow = _noon;

  void start({Duration interval = Duration.zero, bool withDb = true}) {
    clockNow = _noon;
    db = LibraryDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(withDb ? db : null),
        libraryBrowseRefreshIntervalProvider.overrideWithValue(interval),
        homeClockProvider.overrideWithValue(() => clockNow),
      ],
    );
    seen = [];
    container.listen(homeDataVersionProvider, (_, next) => seen.add(next));
  }

  /// Runs a database write in real time (drift's isolate-free executor needs
  /// the real event loop), then lets the fake-time zone deliver the table
  /// update to the provider.
  Future<T> write<T>(WidgetTester tester, Future<T> Function() body) async {
    final result = await tester.runAsync(body);
    await tester.pump();
    return result as T;
  }

  Future<int> insertPlay(int at) => db
      .into(db.plays)
      .insert(PlaysCompanion.insert(path: '/m/a.flac', playedAt: at));

  Future<void> touchTracks() =>
      db.customUpdate('UPDATE tracks SET title = title', updates: {db.tracks});

  /// Subscribes and gives drift's stream machinery its first run.
  Future<void> ready(WidgetTester tester) async {
    await tester.runAsync(() => db.customSelect('SELECT 1').get());
    await tester.pump();
  }

  /// A widget test that disposes the container before the binding checks for
  /// pending timers, which it does before any tearDown runs.
  void pageTest(String name, Future<void> Function(WidgetTester tester) body) {
    testWidgets(name, (tester) async {
      await body(tester);
      container.dispose();
      await tester.pump();
    });
  }

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('which batches count: updates only do not, anything else does', () {
    start();
    TableUpdate on(UpdateKind? kind) => TableUpdate('plays', kind: kind);
    expect(homeBatchChangesRows({on(UpdateKind.update)}), isFalse);
    expect(homeBatchChangesRows({on(UpdateKind.insert)}), isTrue);
    expect(homeBatchChangesRows({on(UpdateKind.delete)}), isTrue);
    expect(homeBatchChangesRows({on(null)}), isTrue);
  });

  pageTest('a batch of inserts bumps once, after the debounce', (tester) async {
    start();
    await ready(tester);

    await write(tester, () => insertPlay(1));
    await write(tester, () => insertPlay(2));
    await write(tester, () => insertPlay(3));
    await tester.pump(homePlaysDebounce - const Duration(milliseconds: 10));
    expect(seen, isEmpty);
    await tester.pump(const Duration(milliseconds: 10));

    expect(seen, [1]);
  });

  pageTest('a listened_ms checkpoint does not bump', (tester) async {
    start();
    await ready(tester);
    final id = await write(tester, () => insertPlay(1));
    await tester.pump(homePlaysDebounce);
    seen.clear();

    await write(tester, () => db.setPlayListened(id, 30000));
    await tester.pump(homePlaysDebounce * 2);

    expect(seen, isEmpty);
  });

  pageTest('deleting a play bumps', (tester) async {
    start();
    await ready(tester);
    final id = await write(tester, () => insertPlay(1));
    await tester.pump(homePlaysDebounce);
    seen.clear();

    await write(
      tester,
      () => (db.delete(db.plays)..where((p) => p.id.equals(id))).go(),
    );
    await tester.pump(homePlaysDebounce);

    expect(seen, [2]);
  });

  pageTest('a track change bumps now and a burst once more at the end', (
    tester,
  ) async {
    start(interval: const Duration(seconds: 2));
    await ready(tester);

    for (var i = 0; i < 5; i++) {
      await write(tester, touchTracks);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(seen, [1]);
    await tester.pump(const Duration(seconds: 2));

    expect(seen, [1, 2]);
  });

  pageTest('no timer waits for midnight: time passing alone does not bump', (
    tester,
  ) async {
    start();
    await tester.pump(const Duration(days: 2));
    expect(seen, isEmpty);
  });

  pageTest('checkDay bumps once when the day changed, not before', (
    tester,
  ) async {
    start();
    final notifier = container.read(homeDataVersionProvider.notifier);

    notifier.checkDay();
    clockNow = DateTime(2026, 10, 24, 23, 59);
    notifier.checkDay();
    expect(seen, isEmpty, reason: 'still the same day');

    clockNow = DateTime(2026, 10, 25, 0, 1);
    notifier.checkDay();
    notifier.checkDay();
    expect(seen, [1], reason: 'the new day counts once');

    clockNow = DateTime(2026, 10, 26, 8);
    notifier.checkDay();
    expect(seen, [1, 2]);
  });

  pageTest('a rebuild of the provider still bumps afterwards', (tester) async {
    start(interval: const Duration(seconds: 2));
    await ready(tester);
    await write(tester, touchTracks);
    await write(tester, touchTracks); // leaves the cooldown running and dirty

    container.invalidate(homeDataVersionProvider);
    // The rebuild is scheduled, not run at once.
    await tester.pump(const Duration(milliseconds: 1));
    await ready(tester);
    seen.clear();

    await write(tester, () => insertPlay(1));
    await tester.pump(homePlaysDebounce);
    expect(seen, [1]);

    // A track change right after the rebuild is not held by the old cooldown.
    await write(tester, touchTracks);
    expect(seen, [1, 2]);
  });

  pageTest('without a library nothing is subscribed or scheduled', (
    tester,
  ) async {
    start(withDb: false);
    expect(container.read(homeDataVersionProvider), 0);
    clockNow = DateTime(2026, 10, 30);
    container.read(homeDataVersionProvider.notifier).checkDay();
    await tester.pump(const Duration(days: 2));
    expect(seen, isEmpty);
  });

  // The test binding fails a test that ends with a timer pending, so this
  // proves that nothing is left running after dispose.
  pageTest('no timer is left after dispose, mid-debounce and mid-cooldown', (
    tester,
  ) async {
    start(interval: const Duration(seconds: 2));
    await ready(tester);

    await write(tester, () => insertPlay(1)); // debounce running
    await write(tester, touchTracks); // cooldown running
    await write(tester, touchTracks); // and dirty
  });
}
