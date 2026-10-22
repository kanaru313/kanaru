// Times the full search (songs page, match count, album and artist filters)
// on a 50k-track file database read through the background isolate. Off by
// default; run with
//   KANARU_BENCH=1 flutter test test/core/database/search_benchmark_test.dart
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_keys_backfill.dart';
import 'package:kanaru/core/database/library_search_queries.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/search_name_index.dart';
import 'package:kanaru/core/database/search_terms.dart';
import 'package:kanaru/core/database/text_keys.dart';

import 'search_bench_rows.dart';

const _total = 50000;
const _batch = 512;
const _runs = 30;
const _budget = Duration(milliseconds: 50);

final _enabled = Platform.environment['KANARU_BENCH'] == '1';

const _queries = [
  's',
  'so',
  'son tu',
  'Sơn Tùng',
  'đi',
  'pop',
  'zzqx',
  'the',
  'the love di',
];

Future<(LibraryDatabase, Directory)> _openFilled() async {
  final dir = Directory.systemTemp.createTempSync('kanaru_search_bench');
  final db = LibraryDatabase(
    NativeDatabase.createInBackground(
      File('${dir.path}/library.db'),
      setup: applyLibraryPragmas,
    ),
  );
  final rows = benchSearchRows(
    (await db.addRoots(['/m'], now: 1)).single,
    count: _total,
  );
  final sw = Stopwatch()..start();
  for (var i = 0; i < rows.length; i += _batch) {
    await db.upsertTracks(rows.sublist(i, min(i + _batch, rows.length)));
  }
  print('wrote $_total rows with index: ${sw.elapsedMilliseconds} ms');
  return (db, dir);
}

int _percentile(List<int> sorted, double p) =>
    sorted[((sorted.length - 1) * p).round()];

void main() {
  test(
    'full search stays under 50 ms at 50k tracks',
    () async {
      final (db, dir) = await _openFilled();
      final albums = albumSearchIndex(await db.albums());
      final artists = artistSearchIndex(await db.artistCredits());
      var worst = 0;
      for (final query in _queries) {
        final terms = searchTerms(query);
        Future<SongSearchResult> run() async {
          final songs = await db.searchSongs(terms);
          albums.match(terms);
          artists.match(terms);
          return songs;
        }

        SongSearchResult? last;
        for (var i = 0; i < 3; i++) {
          last = await run();
        }
        final micros = <int>[];
        for (var i = 0; i < _runs; i++) {
          final sw = Stopwatch()..start();
          last = await run();
          micros.add(sw.elapsedMicroseconds);
        }
        micros.sort();
        final p95 = _percentile(micros, 0.95);
        worst = max(worst, p95);
        print(
          '"$query": songs ${last!.total} (page ${last.songs.length}), '
          'albums ${albums.match(terms).length}, '
          'artists ${artists.match(terms).length}, '
          'p50 ${_percentile(micros, 0.5) / 1000} ms, p95 ${p95 / 1000} ms',
        );
      }
      await db.close();
      dir.deleteSync(recursive: true);
      expect(worst, lessThan(_budget.inMicroseconds));
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'index upkeep costs at 50k tracks',
    () async {
      final (db, dir) = await _openFilled();
      var sw = Stopwatch()..start();
      await db.customStatement(
        "INSERT INTO track_search(track_search) VALUES ('rebuild')",
      );
      print('rebuild: ${sw.elapsedMilliseconds} ms');
      sw = Stopwatch()..start();
      await backfillLibraryKeys(db, version: textKeysVersion + 1);
      print('re-key at a higher version: ${sw.elapsedMilliseconds} ms');
      sw = Stopwatch()..start();
      final albumList = await db.albums();
      final creditList = await db.artistCredits();
      print('cold albums + artistCredits: ${sw.elapsedMilliseconds} ms');
      sw = Stopwatch()..start();
      albumSearchIndex(albumList);
      artistSearchIndex(creditList);
      print(
        'name indexes of ${albumList.length} albums, ${creditList.length} '
        'artists: ${sw.elapsedMilliseconds} ms',
      );
      await db.close();
      dir.deleteSync(recursive: true);
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
