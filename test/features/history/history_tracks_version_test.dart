import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/features/history/history_tracks_version.dart';
import 'package:kanaru/shared/library_browse_refresh.dart';

void main() {
  late LibraryDatabase db;
  late ProviderContainer container;
  late List<int> seen;

  Future<void> change() =>
      db.customUpdate('UPDATE tracks SET title = title', updates: {db.tracks});

  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  void start(Duration interval) {
    db = LibraryDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(db),
        libraryBrowseRefreshIntervalProvider.overrideWithValue(interval),
      ],
    );
    seen = [];
    container.listen(historyTracksVersionProvider, (_, next) => seen.add(next));
  }

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('with no interval every change bumps', () async {
    start(Duration.zero);
    await wait(20);

    await change();
    await wait(30);
    await change();
    await wait(30);

    expect(seen, [1, 2]);
  });

  test('a burst inside the interval bumps now and once at its end', () async {
    start(const Duration(milliseconds: 200));
    await wait(20);

    for (var i = 0; i < 5; i++) {
      await change();
      await wait(10);
    }
    expect(seen, [1]);
    await wait(300);

    expect(seen, [1, 2]);
  });

  test('a quiet interval bumps nothing more', () async {
    start(const Duration(milliseconds: 100));
    await wait(20);

    await change();
    await wait(300);

    expect(seen, [1]);
  });
}
