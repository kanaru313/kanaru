import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/library_sql_functions.dart';
import 'package:kanaru/core/settings/library_sort.dart';
import 'package:kanaru/features/library/library_browse_refresh.dart';
import 'package:kanaru/features/library/songs/songs_list_provider.dart';

void main() {
  test('every Songs sort field maps to its database order', () {
    const table = {
      SongSortField.title: SongOrder.title,
      SongSortField.artist: SongOrder.artist,
      SongSortField.album: SongOrder.album,
      SongSortField.year: SongOrder.year,
      SongSortField.dateAdded: SongOrder.dateAdded,
      SongSortField.duration: SongOrder.duration,
    };
    expect(table.keys, SongSortField.values);
    for (final MapEntry(:key, :value) in table.entries) {
      expect(songOrderFor(key), value, reason: key.name);
    }
  });

  test('a scan reloads the list at most once per refresh interval', () async {
    const interval = Duration(milliseconds: 150);
    const batches = 40;
    final db = LibraryDatabase(
      NativeDatabase.memory(setup: registerLibrarySqlFunctions),
    );
    final container = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(db),
        libraryBrowseRefreshIntervalProvider.overrideWithValue(interval),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final rootId = (await db.addRoots(['/m'], now: 1)).single;

    var loads = 0;
    container.listen(songsListProvider, (_, next) {
      if (next.hasValue) loads++;
    });
    final clock = Stopwatch()..start();
    for (var i = 0; i < batches; i++) {
      await db.upsertTracks([
        TracksCompanion.insert(
          rootId: rootId,
          path: '/m/$i.flac',
          mtimeMs: 1,
          sizeBytes: 1,
          title: 'Song $i',
          addedAt: i,
          updatedAt: i,
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
    final scanTime = clock.elapsed;
    // The change made after the last load still gets its own reload.
    await Future<void>.delayed(interval * 3);

    final allowed = (scanTime.inMilliseconds / interval.inMilliseconds).ceil();
    expect(loads, lessThanOrEqualTo(allowed + 1));
    expect(container.read(songsListProvider).requireValue, hasLength(batches));
  });
}
