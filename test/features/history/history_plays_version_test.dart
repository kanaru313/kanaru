import 'dart:async';

import 'package:drift/drift.dart' show TableUpdate, UpdateKind;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/history_play_writes.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/play_history_writes.dart';
import 'package:kanaru/features/history/history_plays_version.dart';

Future<void> _settle() => Future<void>.delayed(
  historyPlaysDebounce + const Duration(milliseconds: 80),
);

Future<int> _insert(LibraryDatabase db, int at) => db
    .into(db.plays)
    .insert(PlaysCompanion.insert(path: '/m/a.flac', playedAt: at));

void main() {
  late LibraryDatabase db;
  late ProviderContainer container;
  late List<int> seen;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [libraryDatabaseProvider.overrideWithValue(db)],
    );
    seen = [];
    container.listen(
      historyPlaysVersionProvider,
      (_, next) => seen.add(next),
      fireImmediately: false,
    );
    // Subscribed to the table now; the first statement gives drift's stream
    // machinery its first run.
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('which batches count: updates only do not, anything else does', () {
    TableUpdate on(UpdateKind? kind) => TableUpdate('plays', kind: kind);
    expect(historyBatchChangesRows({on(UpdateKind.update)}), isFalse);
    expect(historyBatchChangesRows({on(UpdateKind.insert)}), isTrue);
    expect(historyBatchChangesRows({on(UpdateKind.delete)}), isTrue);
    expect(historyBatchChangesRows({on(null)}), isTrue);
    expect(
      historyBatchChangesRows({on(UpdateKind.update), on(UpdateKind.insert)}),
      isTrue,
    );
  });

  test('a listened_ms checkpoint does not bump', () async {
    final id = await _insert(db, 1);
    await _settle();
    seen.clear();

    await db.setPlayListened(id, 30000);
    await _settle();

    expect(seen, isEmpty);
  });

  test('inserts in a row bump once, after the debounce', () async {
    await _insert(db, 1);
    await _insert(db, 2);
    await _insert(db, 3);
    expect(seen, isEmpty);
    await _settle();

    expect(seen, [1]);
  });

  test('a delete bumps and must be applied at once', () async {
    final id = await _insert(db, 1);
    await _settle();
    final version = container.read(historyPlaysVersionProvider.notifier);
    version.applied();
    seen.clear();

    await db.deletePlay(id);
    await _settle();

    expect(seen, hasLength(1));
    expect(version.mustApplyNow, isTrue);
    version.applied();
    expect(version.mustApplyNow, isFalse);
  });

  test('an insert alone may be held back', () async {
    final version = container.read(historyPlaysVersionProvider.notifier);
    await _insert(db, 1);
    await _settle();

    expect(seen, hasLength(1));
    expect(version.mustApplyNow, isFalse);
  });

  test('a restore asked for by the page is not held back', () async {
    final version = container.read(historyPlaysVersionProvider.notifier);
    final id = await _insert(db, 1);
    final play = (await db.deletePlay(id))!;
    await _settle();
    version.applied();

    version.applyNextNow();
    await db.restorePlay(play);
    await _settle();

    expect(version.mustApplyNow, isTrue);
  });

  test('an update with no kind bumps', () async {
    await _insert(db, 1);
    await _settle();
    seen.clear();

    await db.customUpdate(
      'UPDATE plays SET listened_ms = 1',
      updates: {db.plays},
    );
    await _settle();

    expect(seen, hasLength(1));
  });

  test('clearing the whole history bumps', () async {
    await _insert(db, 1);
    await _insert(db, 2);
    await _settle();
    seen.clear();

    await db.clearPlayHistory();
    await _settle();

    expect(seen, hasLength(1));
  });

  test('a page without a library has nothing to listen to', () async {
    final bare = ProviderContainer();
    addTearDown(bare.dispose);
    bare.listen(historyPlaysVersionProvider, (_, _) {});
    expect(bare.read(historyPlaysVersionProvider), 0);
  });

  test('nothing bumps after the page is gone', () async {
    container.dispose();
    await _insert(db, 1);
    await _settle();

    expect(seen, isEmpty);
    // Keep tearDown's dispose harmless.
    container = ProviderContainer();
    unawaited(Future<void>.value());
  });
}
