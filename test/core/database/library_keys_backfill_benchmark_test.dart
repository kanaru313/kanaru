// Times the key backfill on a 100k-track file database, through the same
// background isolate path the app uses. Off by default; run with
//   KANARU_BENCH=1 flutter test test/core/database/library_keys_backfill_benchmark_test.dart
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_keys_backfill.dart';
import 'package:kanaru/core/database/library_keys_provider.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/separator_rules.dart';
import 'package:kanaru/core/database/track_keys.dart';

const _total = 100000;
final _enabled = Platform.environment['KANARU_BENCH'] == '1';

/// A scan keys what it writes; the benchmark needs a library as the previous
/// schema left it, with no keys and no credits.
Future<void> _unkey(LibraryDatabase db) async {
  await db.customStatement(
    "UPDATE tracks SET keys_version = 0, title_sort = '', "
    'artist_sort = NULL, album_sort = NULL, album_artist_key = NULL, '
    'album_title_key = NULL, album_display_artist = NULL, '
    'artist_search = NULL, album_search = NULL, album_artist_search = NULL, '
    'genre_search = NULL',
  );
  await db.customStatement('DELETE FROM track_artists');
}

void main() {
  test('key computation for one 2000-row chunk', () {
    for (var round = 0; round < 4; round++) {
      final watch = Stopwatch()..start();
      for (var i = 0; i < 2000; i++) {
        trackKeysFor(
          title: 'Bài $i',
          artist: 'Ánh $i; Guest ${i % 300}',
          album: 'Album ${i ~/ 12} Đĩa',
          albumArtist: i % 3 == 0 ? null : 'Ánh ${i % 2000}',
        );
      }
      print('trackKeysFor x2000: ${watch.elapsedMicroseconds / 1000} ms');
    }
  }, skip: _enabled ? false : 'set KANARU_BENCH=1');

  test('in-place chunk time', () async {
    final dir = Directory.systemTemp.createTempSync('kanaru_keys_bench');
    addTearDown(() => dir.deleteSync(recursive: true));
    final db = LibraryDatabase(
      NativeDatabase.createInBackground(
        File('${dir.path}/library.db'),
        setup: applyLibraryPragmas,
      ),
    );
    addTearDown(db.close);
    await db.addRoots(['/m'], now: 1);
    await db.upsertTracks([
      for (var i = 0; i < 6000; i++)
        TracksCompanion.insert(
          rootId: 1,
          path: '/m/$i.flac',
          mtimeMs: 1,
          sizeBytes: 1,
          title: 'Bài $i',
          artist: Value('Ánh $i; Guest ${i % 300}'),
          album: Value('Album ${i ~/ 12} Đĩa'),
          albumArtist: Value(i % 3 == 0 ? null : 'Ánh ${i % 2000}'),
          addedAt: 1,
          updatedAt: 1,
        ),
    ]);
    await _unkey(db);
    final watch = Stopwatch()..start();
    var last = 0;
    final chunks = <int>[];
    await backfillLibraryKeys(
      db,
      onProgress: (done, total) {
        chunks.add(watch.elapsedMilliseconds - last);
        last = watch.elapsedMilliseconds;
      },
    );
    print('in-place chunk times (ms, first is the count): $chunks');
  }, skip: _enabled ? false : 'set KANARU_BENCH=1');

  test(
    'keys 100k tracks in the background',
    () async {
      final dir = Directory.systemTemp.createTempSync('kanaru_keys_bench');
      addTearDown(() => dir.deleteSync(recursive: true));
      final db = LibraryDatabase(
        NativeDatabase.createInBackground(
          File('${dir.path}/library.db'),
          setup: applyLibraryPragmas,
        ),
      );
      addTearDown(db.close);
      await db.addRoots(['/m'], now: 1);
      final rnd = Random(1);
      const names = ['Ánh', 'Sơn Tùng', 'Mỹ Tâm', 'Ünïcødé', '漢字', 'Ølsen'];
      for (var start = 0; start < _total; start += 5000) {
        await db.upsertTracks([
          for (var i = start; i < start + 5000; i++)
            TracksCompanion.insert(
              rootId: 1,
              path: '/m/$i.flac',
              mtimeMs: 1,
              sizeBytes: 1,
              title: 'Bài $i ${rnd.nextInt(1 << 20)}',
              artist: Value(
                '${names[i % 6]} ${i % 2000}'
                '${i % 4 == 0 ? '; Guest ${rnd.nextInt(3000)}' : ''}',
              ),
              album: Value(i % 20 == 0 ? null : 'Album ${i ~/ 12} Đĩa'),
              albumArtist: Value(
                i % 3 == 0 ? null : '${names[i % 6]} ${i % 2000}',
              ),
              addedAt: 1,
              updatedAt: 1,
            ),
        ]);
      }

      await _unkey(db);
      final watch = Stopwatch()..start();
      var lastDone = 0;
      await runKeysBackfillInBackground(
        db,
        defaultArtistRules,
        (done, total) => lastDone = done,
      );
      watch.stop();
      print('backfill $_total tracks: ${watch.elapsedMilliseconds} ms');
      expect(lastDone, _total);
    },
    skip: _enabled ? false : 'set KANARU_BENCH=1',
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
