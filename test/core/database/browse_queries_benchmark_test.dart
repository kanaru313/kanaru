// Times the production browse SQL on a 100k-track file database, and a scan's
// writes with and without an open albums watch. Off by default; run with
//   KANARU_BENCH=1 flutter test test/core/database/browse_queries_benchmark_test.dart
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';

const _total = 100000;

/// Same size as the indexer's tag batches.
const _batch = 512;

final _enabled = Platform.environment['KANARU_BENCH'] == '1';

/// 100k rows like the indexer writes: ~8.3k albums, long and non-ASCII
/// names, a quarter of the tracks with a guest artist, a third of the albums
/// without album artist, some tracks without album.
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
            '${aa % 50 == 0 ? ' with a very long name' * 10 : ''}';
        final compilation = albumNo % 25 == 0;
        final artist = compilation
            ? 'Solo ${rnd.nextInt(5000)}'
            : (i % 4 == 0 ? '$name; Guest ${rnd.nextInt(3000)}' : name);
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
      await _scan(db, rows);

      Future<int> sqlOnly(String sql, [List<Object> vars = const []]) async =>
          (await db
                  .customSelect(
                    'SELECT count(*) AS n FROM ($sql)',
                    variables: [for (final v in vars) Variable(v)],
                  )
                  .getSingle())
              .read<int>('n');

      // Watch streams of the same query share a cached result; marking the
      // table changed forces each timed `first` to run the query again.
      Future<int> fresh<T>(Stream<List<T>> Function() watch) async {
        db.markTablesUpdated({db.tracks});
        return (await watch().first).length;
      }

      final albumKey = (await db.watchAlbums().first)[100].key;
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
        'Dart albums': await _median(() => fresh(db.watchAlbums)),
        'Dart artist credits': await _median(
          () => fresh(db.watchArtistCredits),
        ),
        'Dart album tracks': await _median(
          () => fresh(() => db.watchAlbumTracks(albumKey)),
        ),
        'Dart artist tracks': await _median(
          () => fresh(() => db.watchArtistTracks(artistKey)),
        ),
        for (final order in SongOrder.values) ...{
          'SQL songs ${order.name}': await _median(
            () => sqlOnly(
              'SELECT id FROM tracks ORDER BY ${songsOrderSql(order)}',
            ),
          ),
          'Dart songs ${order.name}': await _median(
            () => fresh(() => db.watchSongs(order: order)),
          ),
        },
      };
      await db.close();
      dir.deleteSync(recursive: true);

      // A first scan into an empty database, without and with a listener.
      Future<int> scanInto({
        required bool watching,
        Duration readTime = Duration.zero,
      }) async {
        final scanDir = Directory.systemTemp.createTempSync('kanaru_bench');
        final scanDb = _open(scanDir);
        final scanRows = _rows((await scanDb.addRoots(['/m'], now: 1)).single);
        var emits = 0;
        final sub = watching
            ? scanDb.watchAlbums().listen((_) => emits++)
            : null;
        final ms = await _scan(scanDb, scanRows, readTime: readTime);
        await sub?.cancel();
        await scanDb.close();
        scanDir.deleteSync(recursive: true);
        if (watching) {
          print('albums watch emitted $emits times during the scan');
        }
        return ms;
      }

      for (final e in results.entries) {
        print('${e.key}: median ${e.value.$1} ms, rows ${e.value.$2}');
      }
      for (final readTime in const [
        Duration.zero,
        Duration(milliseconds: 200),
      ]) {
        final without = await scanInto(watching: false, readTime: readTime);
        final withWatch = await scanInto(watching: true, readTime: readTime);
        print(
          'scan of $_total in batches of $_batch, ${readTime.inMilliseconds} ms '
          'tag read per batch: $without ms without watch, $withWatch ms with '
          'an albums watch '
          '(${((withWatch / without - 1) * 100).toStringAsFixed(0)}% slower)',
        );
      }
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
