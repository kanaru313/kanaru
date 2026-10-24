import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/features/home/home_data_version.dart';
import 'package:kanaru/features/home/home_paged_list.dart';

/// A version provider that goes up only when the test says so.
class _ManualVersion extends HomeDataVersion {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

void main() {
  late LibraryDatabase db;
  late ProviderContainer container;
  late _ManualVersion version;
  // Every (limit, offset) the reader was asked for.
  late List<(int, int)> reads;
  late int total;
  late bool failNext;
  // When set, every read waits for it before it answers.
  Completer<void>? gate;

  late NotifierProvider<HomePagedList<int>, HomePagedState<int>> pages;

  void start({int rows = 450, bool withDb = true}) {
    db = LibraryDatabase(NativeDatabase.memory());
    reads = [];
    total = rows;
    failNext = false;
    gate = null;
    version = _ManualVersion();
    pages =
        NotifierProvider.autoDispose<HomePagedList<int>, HomePagedState<int>>(
          () => HomePagedList<int>(
            read: (db, now, limit, offset) async {
              reads.add((limit, offset));
              await gate?.future;
              if (failNext) {
                failNext = false;
                throw StateError('read failed');
              }
              final end = (offset + limit).clamp(0, total);
              return [for (var i = offset; i < end; i++) i];
            },
            keyOf: (row) => row,
          ),
        );
    container = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(withDb ? db : null),
        homeDataVersionProvider.overrideWith(() => version),
      ],
    );
    container.listen(pages, (_, _) {});
  }

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('reads the first page, then the next ones until a short page', () async {
    start();
    await settle();
    expect(container.read(pages).rows, hasLength(200));
    expect(container.read(pages).done, isFalse);

    await container.read(pages.notifier).loadMore();
    expect(container.read(pages).rows, hasLength(400));
    expect(container.read(pages).done, isFalse);

    await container.read(pages.notifier).loadMore();
    expect(container.read(pages).rows, hasLength(450));
    expect(container.read(pages).done, isTrue);
    expect(reads, [(200, 0), (200, 200), (200, 400)]);

    await container.read(pages.notifier).loadMore();
    expect(reads, hasLength(3), reason: 'nothing is read after the end');
  });

  test('a page of exactly the page size is not the end', () async {
    start(rows: 200);
    await settle();
    expect(container.read(pages).done, isFalse);
    await container.read(pages.notifier).loadMore();
    expect(container.read(pages).done, isTrue);
    expect(container.read(pages).rows, hasLength(200));
  });

  test('a change reads every loaded row again in one query', () async {
    start();
    await settle();
    await container.read(pages.notifier).loadMore();
    reads.clear();
    total = 460;

    version.bump();
    await settle();

    expect(reads, [(400, 0)]);
    expect(container.read(pages).rows, hasLength(400));
    expect(container.read(pages).rows.first, 0);
  });

  test('a change after the end picks up rows that arrived', () async {
    start(rows: 30);
    await settle();
    expect(container.read(pages).done, isTrue);
    total = 35;

    version.bump();
    await settle();

    expect(reads.last, (200, 0));
    expect(container.read(pages).rows, hasLength(35));
    expect(container.read(pages).done, isTrue);
  });

  test('a row that two pages both return is kept once', () async {
    start(rows: 300);
    await settle();
    // The data shifted by one between the reads: row 199 comes up again.
    reads.clear();
    final shifted =
        NotifierProvider.autoDispose<HomePagedList<int>, HomePagedState<int>>(
          () => HomePagedList<int>(
            read: (db, now, limit, offset) async => [
              for (var i = offset == 0 ? 0 : 199; i < 300; i++) i,
            ],
            keyOf: (row) => row,
          ),
        );
    container.listen(shifted, (_, _) {});
    await settle();
    await container.read(shifted.notifier).loadMore();
    final rows = container.read(shifted).rows;
    expect(rows, hasLength(300));
    expect(rows.toSet(), hasLength(300));
  });

  test('a failed read stops reading until the data changes', () async {
    start();
    failNext = true;
    await settle();
    expect(container.read(pages).failed, isTrue);
    expect(container.read(pages).rows, isEmpty);

    await container.read(pages.notifier).loadMore();
    expect(reads, hasLength(1), reason: 'no read after a failure');

    version.bump();
    await settle();
    expect(container.read(pages).failed, isFalse);
    expect(container.read(pages).rows, hasLength(200));
  });

  test('retry after a failed later page reads that page again', () async {
    start();
    await settle();
    failNext = true;
    await container.read(pages.notifier).loadMore();
    expect(container.read(pages).failed, isTrue);
    expect(container.read(pages).rows, hasLength(200));

    await container.read(pages.notifier).retry();
    final state = container.read(pages);
    expect(state.failed, isFalse);
    expect(state.rows, hasLength(400));
    expect(reads.last, (200, 200));

    await container.read(pages.notifier).retry();
    expect(reads, hasLength(3), reason: 'retry does nothing without a failure');
  });

  test('retry after a failed reload of a short list reads it again', () async {
    start(rows: 30);
    await settle();
    total = 35;
    failNext = true;
    version.bump();
    await settle();
    expect(container.read(pages).failed, isTrue);
    await container.read(pages.notifier).retry();
    expect(reads.last, (200, 0));
    expect(container.read(pages).rows, hasLength(35));
    expect(container.read(pages).failed, isFalse);
  });

  test('a reload during a page read drops that page', () async {
    start();
    await settle();
    gate = Completer<void>();
    final more = container.read(pages.notifier).loadMore();
    version.bump();
    gate!.complete();
    await more;
    await settle();

    final state = container.read(pages);
    expect(reads, [(200, 0), (200, 200), (200, 0)]);
    expect(state.rows, [for (var i = 0; i < 200; i++) i]);
    expect(state.loading, isFalse);
    expect(state.done, isFalse);
  });

  test('two quick changes keep the rows of the last read once', () async {
    start();
    await settle();
    gate = Completer<void>();
    version.bump();
    version.bump();
    await settle();
    expect(container.read(pages).loading, isTrue);
    gate!.complete();
    await settle();

    final state = container.read(pages);
    expect(reads.where((r) => r == (200, 0)), hasLength(3));
    expect(state.rows, [for (var i = 0; i < 200; i++) i]);
    expect(state.loading, isFalse);
  });

  test('no database gives a finished empty list', () async {
    start(withDb: false);
    await settle();
    final state = container.read(pages);
    expect(state.rows, isEmpty);
    expect(state.done, isTrue);
    expect(state.loading, isFalse);
    expect(reads, isEmpty);
  });
}
