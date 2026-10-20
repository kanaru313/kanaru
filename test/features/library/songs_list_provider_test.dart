import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
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
    final db = LibraryDatabase(NativeDatabase.memory());
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
    final full = Completer<void>();
    container.listen(songsListProvider, (_, next) {
      if (!next.hasValue) return;
      loads++;
      if (next.requireValue.length == batches && !full.isCompleted) {
        full.complete();
      }
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
    await full.future.timeout(const Duration(seconds: 10));

    final allowed = (scanTime.inMilliseconds / interval.inMilliseconds).ceil();
    expect(loads, lessThanOrEqualTo(allowed + 1));
    expect(container.read(songsListProvider).requireValue, hasLength(batches));
  });

  test('changing the sort reloads at once, not after the interval', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(db),
        libraryBrowseRefreshIntervalProvider.overrideWithValue(
          const Duration(hours: 1),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final rootId = (await db.addRoots(['/m'], now: 1)).single;
    await db.upsertTracks([
      for (final (i, title) in ['b', 'a', 'c'].indexed)
        TracksCompanion.insert(
          rootId: rootId,
          path: '/m/$title.flac',
          mtimeMs: 1,
          sizeBytes: 1,
          title: title,
          addedAt: i,
          updatedAt: i,
        ),
    ]);

    List<String> titles() => [
      for (final t in container.read(songsListProvider).requireValue) t.title,
    ];
    final first = Completer<void>();
    final reordered = Completer<void>();
    container.listen(songsListProvider, (_, next) {
      if (!next.hasValue) return;
      final names = [for (final t in next.requireValue) t.title];
      if (!first.isCompleted) {
        first.complete();
      } else if (names.join() == 'cba' && !reordered.isCompleted) {
        reordered.complete();
      }
    });
    await first.future.timeout(const Duration(seconds: 10));
    expect(titles(), ['a', 'b', 'c']);

    container
        .read(settingsProvider.notifier)
        .setSongSort(const SortChoice(SongSortField.title, descending: true));
    await reordered.future.timeout(const Duration(seconds: 10));
    expect(titles(), ['c', 'b', 'a']);
  });
}
