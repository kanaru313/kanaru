import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_search_queries.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/features/search/search_request_provider.dart';
import 'package:kanaru/shared/library_browse_refresh.dart';

import 'search_test_data.dart';

/// Counts the `SELECT DISTINCT language` statements the database runs.
class _DistinctCounter extends QueryInterceptor {
  int count = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains('SELECT DISTINCT language')) count++;
    return executor.runSelect(statement, args);
  }
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue, reason: 'timed out');
}

void main() {
  late _DistinctCounter counter;
  late LibraryDatabase db;
  late ProviderContainer container;
  late int rootId;

  setUp(() async {
    counter = _DistinctCounter();
    db = LibraryDatabase(NativeDatabase.memory().interceptWith(counter));
    rootId = (await db.addRoots(['/m'], now: 1)).single;
    await db.upsertTracks([
      for (final (i, lang) in ['vie', 'eng'].indexed)
        TracksCompanion.insert(
          rootId: rootId,
          path: '/m/$i.flac',
          mtimeMs: 1,
          sizeBytes: 10,
          title: 'a$i',
          language: Value(lang),
          addedAt: 100,
          updatedAt: 100,
        ),
    ]);
    container = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(db),
        libraryBrowseRefreshIntervalProvider.overrideWithValue(Duration.zero),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('typing more of a language query reuses the distinct list', () async {
    final first = container.listen(
      searchSongsProvider(requestFor('language:vi a')),
      (_, _) {},
    );
    await _until(() => first.read().value != null);
    expect(counter.count, 1);

    // The page swaps the request while the old one is still listened to.
    final second = container.listen(
      searchSongsProvider(requestFor('language:vi ab')),
      (_, _) {},
    );
    first.close();
    await _until(() => second.read().value != null);

    expect(counter.count, 1);
  });

  test('an unchanged distinct list does not rebuild the song search', () async {
    final states = <AsyncValue<SongSearchResult>>[];
    container.listen(
      searchSongsProvider(requestFor('language:vi a')),
      (_, next) => states.add(next),
      fireImmediately: true,
    );
    await _until(() => states.any((s) => s.value != null));
    final before = counter.count;
    states.clear();

    // A write that leaves the languages as they were: the distinct list is
    // read again but must not be emitted again.
    await (db.update(db.tracks)..where((t) => t.title.equals('a0'))).write(
      const TracksCompanion(title: Value('a0 renamed')),
    );
    await _until(() => counter.count > before);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(states.any((s) => s.isLoading), isFalse);
  });
}
