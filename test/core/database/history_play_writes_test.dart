import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/history_play_writes.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/play_history_writes.dart';

void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> play(String path, int at, {int? listened}) => db
      .into(db.plays)
      .insert(
        PlaysCompanion.insert(
          path: path,
          playedAt: at,
          listenedMs: Value(listened),
        ),
      );

  // play_stats equals GROUP BY over plays, in both directions.
  Future<void> expectStatsMatchPlays() async {
    Future<List<String>> keys(String sql) async =>
        ((await db.customSelect(sql).get())
              .map(
                (r) =>
                    '${r.data['path']}|${r.data['c']}|${r.data['f']}|${r.data['l']}',
              )
              .toList())
          ..sort();
    expect(
      await keys(
        'SELECT path, play_count AS c, first_played_at AS f, '
        'last_played_at AS l FROM play_stats',
      ),
      await keys(
        'SELECT path, COUNT(*) AS c, MIN(played_at) AS f, MAX(played_at) AS l '
        'FROM plays GROUP BY path',
      ),
    );
  }

  Future<int> playCount() async => (await db.select(db.plays).get()).length;

  test('deletePlay returns the old row and stats follow', () async {
    await play('/a', 10);
    final id = await play('/a', 20, listened: 5000);
    await play('/b', 30);
    final old = await db.deletePlay(id);
    expect(old?.id, id);
    expect(old?.path, '/a');
    expect(old?.playedAt, 20);
    expect(old?.listenedMs, 5000);
    expect(await playCount(), 2);
    await expectStatsMatchPlays();
  });

  test('deleting the only play of a path removes its stats row', () async {
    final id = await play('/a', 10);
    await db.deletePlay(id);
    expect(await db.select(db.playStats).get(), isEmpty);
  });

  test('deletePlay of a missing id is null and changes nothing', () async {
    await play('/a', 10);
    expect(await db.deletePlay(999), isNull);
    expect(await playCount(), 1);
    await expectStatsMatchPlays();
  });

  test('restorePlay brings back the same id and columns', () async {
    await play('/a', 10);
    final id = await play('/a', 20, listened: 7000);
    await play('/a', 30);
    final old = (await db.deletePlay(id))!;
    expect(await db.restorePlay(old), isTrue);
    final back = await (db.select(
      db.plays,
    )..where((p) => p.id.equals(id))).getSingle();
    expect(back.path, '/a');
    expect(back.playedAt, 20);
    expect(back.listenedMs, 7000);
    await expectStatsMatchPlays();
  });

  test('restorePlay twice writes once', () async {
    await play('/a', 10);
    final old = (await db.deletePlay(await play('/a', 20)))!;
    expect(await db.restorePlay(old), isTrue);
    expect(await db.restorePlay(old), isFalse);
    expect(await playCount(), 2);
    await expectStatsMatchPlays();
  });

  test('restorePlay keeps a null listened_ms null', () async {
    final old = (await db.deletePlay(await play('/a', 10)))!;
    await db.restorePlay(old);
    expect((await db.select(db.plays).getSingle()).listenedMs, isNull);
  });

  test('a restored play can be checkpointed again', () async {
    final id = await play('/a', 10, listened: 1);
    final old = (await db.deletePlay(id))!;
    expect(await db.setPlayListened(id, 2), isFalse);
    await db.restorePlay(old);
    expect(await db.setPlayListened(id, 40000), isTrue);
    expect((await db.select(db.plays).getSingle()).listenedMs, 40000);
  });

  test('restores a play whose track is not in the library', () async {
    final old = (await db.deletePlay(await play('/gone/x.flac', 10)))!;
    expect(await db.restorePlay(old), isTrue);
    expect((await db.select(db.playStats).getSingle()).path, '/gone/x.flac');
  });

  test('delete and restore notify watchers of plays', () async {
    final id = await play('/a', 10);
    final kinds = <UpdateKind?>[];
    final sub = db
        .tableUpdates(TableUpdateQuery.onTable(db.plays))
        .listen((updates) => kinds.addAll(updates.map((u) => u.kind)));
    addTearDown(sub.cancel);
    final old = (await db.deletePlay(id))!;
    await db.restorePlay(old);
    await Future<void>.delayed(Duration.zero);
    expect(kinds, containsAll([UpdateKind.delete, UpdateKind.insert]));
  });

  group('several plays', () {
    test('delete by ids returns the rows newest first; stats follow', () async {
      final a1 = await play('/a', 10);
      final b = await play('/b', 20);
      final a2 = await play('/a', 30, listened: 7);
      await play('/c', 40);
      final old = await db.deletePlaysByIds([a1, b, a2, 9999]);
      expect(old.map((p) => p.id), [a2, b, a1]);
      expect(old.first.listenedMs, 7);
      expect(await playCount(), 1);
      await expectStatsMatchPlays();
    });

    test(
      'restore puts every row back with its id; stats equal before',
      () async {
        final ids = [
          await play('/a', 10),
          await play('/b', 20, listened: 3),
          await play('/a', 30),
        ];
        final old = await db.deletePlaysByIds(ids);
        expect(await playCount(), 0);
        expect(await db.restorePlays(old), 3);
        expect(
          (await db.select(db.plays).get()).map((p) => p.id).toSet(),
          ids.toSet(),
        );
        await expectStatsMatchPlays();
      },
    );

    test('restore skips ids that exist (a second Undo)', () async {
      final ids = [await play('/a', 10), await play('/a', 20)];
      final old = await db.deletePlaysByIds(ids);
      expect(await db.restorePlays(old), 2);
      expect(await db.restorePlays(old), 0);
      expect(await playCount(), 2);
      await expectStatsMatchPlays();
    });

    test('more ids than SQLite variables allow', () async {
      final ids = <int>[];
      await db.batch((b) {
        for (var i = 0; i < 1200; i++) {
          b.insert(
            db.plays,
            PlaysCompanion.insert(path: '/p${i % 7}', playedAt: i),
          );
        }
      });
      ids.addAll((await db.select(db.plays).get()).map((p) => p.id));
      final old = await db.deletePlaysByIds(ids);
      expect(old, hasLength(1200));
      expect(old.first.playedAt, 1199);
      expect(await playCount(), 0);
      expect(await db.restorePlays(old), 1200);
      await expectStatsMatchPlays();
    });
  });
}
