// Times the production browse SQL on a 100k-track file database, and a scan's
// writes with the Songs list or an album page open. Off by default; run with
//   KANARU_BENCH=1 flutter test test/core/database/browse_queries_benchmark_test.dart
// (add --plain-name 'browse queries' for the query timings only).
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_song_paging.dart';
import 'package:kanaru/core/database/track_keys.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/throttled_tracks_query.dart';

/// How the albums or Songs query is listened to during a timed scan.
enum _Listener { none, throttled, albumPage, songsWatch, songsThrottled }

const _total = 100000;

/// Same size as the indexer's tag batches.
const _batch = 512;

final _enabled = Platform.environment['KANARU_BENCH'] == '1';

/// 100k rows like the indexer writes: ~8.3k albums, long and non-ASCII
/// names, a quarter of the tracks with a guest artist, a third of the albums
/// without album artist, some tracks without album. Guests are joined in
/// the ways real tags do (`; `, `;`, ` feat. `, ` / `).
List<TracksCompanion> _rows(int rootId) {
  final rnd = Random(1);
  const accents = ['Ánh', 'Sơn Tùng', 'Mỹ Tâm', 'Ünïcødé', '漢字', 'Ølsen'];
  return [
    for (var i = 0; i < _total; i++)
      () {
        final albumNo = i ~/ 12;
        final aa = albumNo % 2000;
        final name =
            '${accents[aa % accents.length]} Artist $aa'
            '${aa % 50 == 0 ? ' and a very long name' * 10 : ''}';
        final compilation = albumNo % 25 == 0;
        final artist = compilation
            ? 'Solo ${rnd.nextInt(5000)}'
            : (i % 4 == 0
                  ? '$name${const ['; ', ';', ' feat. ', ' / '][i % 16 ~/ 4]}'
                        'Guest ${rnd.nextInt(3000)}'
                  : name);
        return TracksCompanion.insert(
          rootId: rootId,
          path: '/m/$aa/$albumNo/$i.flac',
          mtimeMs: 1,
          sizeBytes: 1,
          title: 'Bài $i ${rnd.nextInt(1 << 30)}',
          artist: Value(artist),
          album: Value(i % 20 == 0 ? null : 'Album ${albumNo % 6000} Đĩa'),
          albumArtist: Value(
            compilation ? 'Various Artists' : (albumNo % 3 == 0 ? null : name),
          ),
          discNo: Value(1 + (i % 12) ~/ 6),
          trackNo: Value(1 + i % 6),
          year: Value(1960 + albumNo % 60),
          durationMs: Value(180000 + rnd.nextInt(120000)),
          addedAt: i,
          updatedAt: i,
        );
      }(),
  ];
}

LibraryDatabase _open(Directory dir) => LibraryDatabase(
  NativeDatabase.createInBackground(
    File('${dir.path}/library.db'),
    setup: applyLibraryPragmas,
  ),
);

/// The Songs list as a plain drift watch: reloads in full after every write.
/// The app no longer has one; it is kept here to show what the throttled
/// refresh saves during a scan.
Stream<List<QueryRow>> _plainSongsWatch(LibraryDatabase db) =>
    db.customSelect(songsSql(SongOrder.title), readsFrom: {db.tracks}).watch();

/// Median of 5 timed runs after one warm-up; returns (ms, rows).
Future<(int, int)> _median(Future<int> Function() run) async {
  await run();
  final runs = <int>[];
  var n = 0;
  for (var i = 0; i < 5; i++) {
    final sw = Stopwatch()..start();
    n = await run();
    runs.add(sw.elapsedMilliseconds);
  }
  runs.sort();
  return (runs[2], n);
}

/// Writes [rows] in batches; [readTime] stands in for reading a batch's tags,
/// during which the database isolate is idle.
Future<int> _scan(
  LibraryDatabase db,
  List<TracksCompanion> rows, {
  Duration readTime = Duration.zero,
}) async {
  final sw = Stopwatch()..start();
  for (var i = 0; i < rows.length; i += _batch) {
    if (readTime > Duration.zero) await Future<void>.delayed(readTime);
    await db.upsertTracks(rows.sublist(i, min(i + _batch, rows.length)));
  }
  return sw.elapsedMilliseconds;
}

void main() {
  test(
    'browse queries on 100k tracks',
    () async {
      final dir = Directory.systemTemp.createTempSync('kanaru_bench');
      final db = _open(dir);
      final rows = _rows((await db.addRoots(['/m'], now: 1)).single);
      print('first scan of $_total: ${await _scan(db, rows)} ms');

      Future<int> sqlOnly(String sql, [List<Object> vars = const []]) async =>
          (await db
                  .customSelect(
                    'SELECT count(*) AS n FROM ($sql)',
                    variables: [for (final v in vars) Variable(v)],
                  )
                  .getSingle())
              .read<int>('n');

      final albumKey = (await db.albums())[100].key;
      const artistKey = 'guest 7';
      final results = <String, (int, int)>{
        'SQL albums': await _median(() => sqlOnly(albumsSql)),
        'SQL artist credits': await _median(() => sqlOnly(artistCreditsSql)),
        'SQL album tracks': await _median(
          () =>
              sqlOnly(albumTracksSql, [albumKey.artistKey, albumKey.titleKey]),
        ),
        'SQL artist tracks': await _median(
          () => sqlOnly(artistTracksSql, [artistKey]),
        ),
        'Dart albums': await _median(() async => (await db.albums()).length),
        'Dart artist credits': await _median(
          () async => (await db.artistCredits()).length,
        ),
        'Dart album tracks': await _median(
          () async => (await db.albumTracks(albumKey)).length,
        ),
        'Dart artist tracks': await _median(
          () async => (await db.artistTracks(artistKey)).length,
        ),
        for (final order in SongOrder.values) ...{
          'SQL songs ${order.name}': await _median(
            () => sqlOnly(
              'SELECT id FROM tracks ORDER BY ${songsOrderSql(order)}',
            ),
          ),
          'Dart songs ${order.name}': await _median(
            () async => (await db.songs(order: order)).length,
          ),
          'Dart song ids ${order.name} + first page': await _median(() async {
            final ids = await db.songIds(order: order);
            return (await db.songsByIds(ids.take(songPageSize).toList()))
                .length;
          }),
        },
      };
      await db.close();
      dir.deleteSync(recursive: true);

      for (final e in results.entries) {
        print('${e.key}: median ${e.value.$1} ms, rows ${e.value.$2}');
      }
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'scan of 100k tracks with a list open',
    () async {
      // A first scan into an empty database, with the Songs list or an album
      // page listened to in different ways. Runs alternate so machine load
      // hits all alike.
      Future<int> scanInto(
        _Listener listener, {
        Duration readTime = Duration.zero,
      }) async {
        final scanDir = Directory.systemTemp.createTempSync('kanaru_bench');
        final scanDb = _open(scanDir);
        final scanRows = _rows((await scanDb.addRoots(['/m'], now: 1)).single);
        var emits = 0;
        final loadTime = Stopwatch();
        Future<T> timed<T>(Future<T> Function() load) async {
          loadTime.start();
          try {
            return await load();
          } finally {
            loadTime.stop();
          }
        }

        // An album of the scan (row 101 has one), as its open page asks.
        final page = scanRows[101];
        final pageKey = AlbumKey(
          albumArtistKey(page.albumArtist.value, page.artist.value),
          albumTitleKey(page.album.value!),
        );

        final sub = switch (listener) {
          _Listener.none => null,
          _Listener.throttled => throttledTracksQuery(
            scanDb,
            () => timed(scanDb.albums),
            interval: const Duration(seconds: 2),
          ).listen((_) => emits++),
          _Listener.albumPage => throttledTracksQuery(
            scanDb,
            () => timed(() => scanDb.albumTracks(pageKey)),
            interval: const Duration(seconds: 2),
          ).listen((_) => emits++),
          _Listener.songsWatch => _plainSongsWatch(
            scanDb,
          ).listen((_) => emits++),
          _Listener.songsThrottled => throttledTracksQuery(
            scanDb,
            () => timed(scanDb.songs),
            interval: const Duration(seconds: 2),
          ).listen((_) => emits++),
        };
        final ms = await _scan(scanDb, scanRows, readTime: readTime);
        await sub?.cancel();
        await scanDb.close();
        scanDir.deleteSync(recursive: true);
        if (sub != null) {
          print(
            '  ${listener.name}: $emits results, '
            '${loadTime.elapsedMilliseconds} ms in throttled loads',
          );
        }
        return ms;
      }

      int median(List<int> runs) => (runs.toList()..sort())[runs.length ~/ 2];
      String slower(int ms, int base) =>
          '${((ms / base - 1) * 100).toStringAsFixed(0)}%';

      for (final readTime in const [
        Duration.zero,
        Duration(milliseconds: 15),
      ]) {
        final alone = <int>[];
        final throttled = <int>[];
        final albumPage = <int>[];
        final songsThrottled = <int>[];
        for (var i = 0; i < 3; i++) {
          alone.add(await scanInto(_Listener.none, readTime: readTime));
          throttled.add(
            await scanInto(_Listener.throttled, readTime: readTime),
          );
          albumPage.add(
            await scanInto(_Listener.albumPage, readTime: readTime),
          );
          songsThrottled.add(
            await scanInto(_Listener.songsThrottled, readTime: readTime),
          );
        }
        final songsWatched = await scanInto(
          _Listener.songsWatch,
          readTime: readTime,
        );
        final base = median(alone);
        print(
          'scan of $_total in batches of $_batch, '
          '${readTime.inMilliseconds} ms tag read per batch: alone $alone '
          '(median $base ms); albums throttled $throttled (median '
          '${median(throttled)} ms, ${slower(median(throttled), base)}); '
          'album page throttled $albumPage (median ${median(albumPage)} ms, '
          '${slower(median(albumPage), base)}); '
          'songs throttled $songsThrottled (median '
          '${median(songsThrottled)} ms, '
          '${slower(median(songsThrottled), base)}); '
          'songs watch $songsWatched ms (${slower(songsWatched, base)})',
        );
      }
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 40)),
  );
}
