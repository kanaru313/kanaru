import 'dart:math';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/playlist_queries.dart';

void main() {
  late LibraryDatabase db;
  late int id;
  late List<int> entryIds;

  Future<List<int>> storedOrder(int playlist) async {
    final rows =
        await (db.select(db.playlistEntries)
              ..where((e) => e.playlistId.equals(playlist))
              ..orderBy([(e) => OrderingTerm.asc(e.position)]))
            .get();
    expect(rows.map((e) => e.position), [
      for (var i = 0; i < rows.length; i++) i,
    ]);
    return [for (final e in rows) e.id];
  }

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    id = await db.createPlaylist(
      'A',
      now: 1,
      paths: [for (var i = 0; i < 30; i++) '/m/$i'],
    );
    entryIds = await storedOrder(id);
  });
  tearDown(() => db.close());

  test('300 random moves match list semantics and stay dense', () async {
    final random = Random(1);
    final model = [...entryIds];
    for (var step = 0; step < 300; step++) {
      final from = random.nextInt(model.length);
      final to = random.nextInt(model.length);
      final moved = model.removeAt(from);
      model.insert(to, moved);

      await db.movePlaylistEntry(id, moved, to);

      expect(await storedOrder(id), model, reason: 'step $step');
    }
  });

  test('a target past the end goes last; a negative one goes first', () async {
    await db.movePlaylistEntry(id, entryIds.first, 99);
    expect((await storedOrder(id)).last, entryIds.first);

    await db.movePlaylistEntry(id, entryIds[5], -4);
    expect((await storedOrder(id)).first, entryIds[5]);
  });

  test('moving onto the same index writes nothing', () async {
    await db.movePlaylistEntry(id, entryIds[3], 3);

    expect(await storedOrder(id), entryIds);
  });

  test('an entry of another playlist or a missing one throws', () async {
    final other = await db.createPlaylist('B', now: 2, paths: ['/m/x']);
    final foreign = (await storedOrder(other)).single;

    await expectLater(db.movePlaylistEntry(id, foreign, 0), throwsStateError);
    await expectLater(db.movePlaylistEntry(id, 9999, 0), throwsStateError);

    expect(await storedOrder(id), entryIds);
    expect(await storedOrder(other), [foreign]);
  });
}
