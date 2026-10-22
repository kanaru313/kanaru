// Times the listen history reads on a deterministic 300k-play file database,
// through the same background isolate path the app uses. Off by default; run
// with
//   KANARU_BENCH=1 flutter test test/core/database/history_queries_benchmark_test.dart
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/history_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';

final _enabled = Platform.environment['KANARU_BENCH'] == '1';

const _tracks = 20000;
const _totalPlays = 300000;
const _importPlays = 2000;
const _runs = 5;

/// Directory for the database file; the temp dir when unset.
final String? _benchDir = Platform.environment['KANARU_BENCH_DIR'];

String _path(int i) => '/m/$i.flac';

/// Plays per rank: `round(6000 * r^-0.6)` until [_totalPlays] are placed.
List<int> _playsPerRank() {
  final out = <int>[];
  var left = _totalPlays;
  for (var r = 1; left > 0 && r <= _tracks; r++) {
    final n = min(left, (6000 * pow(r, -0.6)).round());
    if (n <= 0) break;
    out.add(n);
    left -= n;
  }
  return out;
}

Future<int> _median(Future<void> Function() query) async {
  await query(); // warm cache
  final times = <int>[];
  for (var i = 0; i < _runs; i++) {
    final watch = Stopwatch()..start();
    await query();
    times.add(watch.elapsedMicroseconds);
  }
  times.sort();
  return times[_runs ~/ 2];
}

void main() {
  test(
    'history reads on 300k plays',
    () async {
      final custom = _benchDir;
      final dir = custom == null
          ? Directory.systemTemp.createTempSync('kanaru_history_bench')
          : Directory(custom).createTempSync('history_bench');
      addTearDown(() => dir.deleteSync(recursive: true));
      final db = LibraryDatabase(
        NativeDatabase.createInBackground(
          File('${dir.path}/library.db'),
          setup: applyLibraryPragmas,
        ),
      );
      addTearDown(db.close);
      final version = await db
          .customSelect('SELECT sqlite_version() AS v')
          .getSingle();
      print('sqlite ${version.read<String>('v')}');

      await db.addRoots(['/m'], now: 1);
      await db.upsertTracks([
        for (var i = 0; i < _tracks; i++)
          TracksCompanion.insert(
            rootId: 1,
            path: _path(i),
            mtimeMs: 1,
            sizeBytes: 1,
            title: 'Bài $i',
            artist: Value('Ánh ${i % 2000}'),
            addedAt: 1,
            updatedAt: 1,
          ),
      ]);

      // Fixed seed; plays spread evenly over five years ending at `end`.
      final rnd = Random(20261023);
      final end = DateTime(2026, 10, 1).millisecondsSinceEpoch;
      final begin = DateTime(2021, 10, 1).millisecondsSinceEpoch;
      final perRank = _playsPerRank();
      final rows = <PlaysCompanion>[
        for (var r = 0; r < perRank.length; r++)
          for (var k = 0; k < perRank[r]; k++)
            PlaysCompanion.insert(
              path: _path(r),
              playedAt: begin + (rnd.nextDouble() * (end - begin)).floor(),
              listenedMs: const Value(60000),
            ),
        // An import: many plays of one extra track at one instant.
        for (var k = 0; k < _importPlays; k++)
          PlaysCompanion.insert(
            path: _path(perRank.length),
            playedAt: begin + (end - begin) ~/ 3,
            listenedMs: const Value(60000),
          ),
      ];
      final load = Stopwatch()..start();
      for (var i = 0; i < rows.length; i += 20000) {
        await db.batch(
          (b) => b.insertAll(
            db.plays,
            rows.sublist(i, min(i + 20000, rows.length)),
          ),
        );
      }
      print('loaded ${rows.length} plays in ${load.elapsedMilliseconds} ms');

      // The year with the most plays.
      var bestYear = 0;
      var bestCount = -1;
      for (var y = 2021; y <= 2026; y++) {
        final c = await db.historyYears(y, y);
        if (c.isEmpty) continue;
        final n = (await db.historyDayCounts(_dayBounds(y)))
            .fold<int>(0, (s, d) => s + d.count);
        if (n > bestCount) {
          bestCount = n;
          bestYear = y;
        }
      }
      final counts = await db.historyDayCounts(_dayBounds(bestYear));
      // The import day is its own case below; the busiest ordinary day here.
      final importAt = begin + (end - begin) ~/ 3;
      final importDayStart = () {
        final d = DateTime.fromMillisecondsSinceEpoch(importAt);
        return DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
      }();
      final busiest = counts
          .where((c) => c.dayStart != importDayStart)
          .reduce((a, b) => a.count >= b.count ? a : b);
      final top1 = _path(0);
      final first = (await db.historyTrackSummary(top1)).firstPlayedAt!;
      final oldestDay = DateTime.fromMillisecondsSinceEpoch(first);
      final oldestStart = DateTime(
        oldestDay.year,
        oldestDay.month,
        oldestDay.day,
      ).millisecondsSinceEpoch;
      final oldestEnd = DateTime(
        oldestDay.year,
        oldestDay.month,
        oldestDay.day + 1,
      ).millisecondsSinceEpoch;
      final importDay = DateTime.fromMillisecondsSinceEpoch(importAt);
      final importStart = DateTime(
        importDay.year,
        importDay.month,
        importDay.day,
      ).millisecondsSinceEpoch;
      final importEnd = DateTime(
        importDay.year,
        importDay.month,
        importDay.day + 1,
      ).millisecondsSinceEpoch;
      final busiestEnd = DateTime.fromMillisecondsSinceEpoch(busiest.dayStart);
      final now = end;
      int ago(int days) {
        final d = DateTime.fromMillisecondsSinceEpoch(now);
        return DateTime(d.year, d.month, d.day - days).millisecondsSinceEpoch;
      }

      final cases = <(String, int, Future<void> Function())>[
        (
          'historyDayCounts(busiest year $bestYear, $bestCount plays)',
          80,
          () => db.historyDayCounts(_dayBounds(bestYear)),
        ),
        (
          'historyDayPlays(busiest day, ${busiest.count} rows)',
          30,
          () => db.historyDayPlays(
            busiest.dayStart,
            DateTime(
              busiestEnd.year,
              busiestEnd.month,
              busiestEnd.day + 1,
            ).millisecondsSinceEpoch,
          ),
        ),
        (
          'historyDayPlays(oldest day of rank-1 track)',
          80,
          () => db.historyDayPlays(oldestStart, oldestEnd),
        ),
        (
          'historyDayPlays(day of $_importPlays equal played_at)',
          150,
          () => db.historyDayPlays(importStart, importEnd),
        ),
        (
          'historyTopPlays(30 days)',
          40,
          () => db.historyTopPlays(start: ago(30), end: now, limit: 500),
        ),
        (
          'historyTopPlays(365 days)',
          350,
          () => db.historyTopPlays(start: ago(365), end: now, limit: 500),
        ),
        (
          'historyTopPlays(all, play_stats)',
          60,
          () => db.historyTopPlays(limit: 500),
        ),
        (
          'historyTrackSummary + historyTrackPlays(rank 1)',
          50,
          () async {
            await db.historyTrackSummary(top1);
            await db.historyTrackPlays(top1);
          },
        ),
      ];
      var failed = 0;
      for (final (name, limitMs, run) in cases) {
        final micros = await _median(run);
        final ok = micros <= limitMs * 1000;
        if (!ok) failed++;
        print(
          '${ok ? 'PASS' : 'FAIL'} $name: '
          '${(micros / 1000).toStringAsFixed(1)} ms (limit $limitMs ms)',
        );
      }
      expect(failed, 0, reason: 'queries over their threshold');
    },
    skip: _enabled ? false : 'set KANARU_BENCH=1',
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

/// Local midnights from 1 January of [year] to 1 January of the next.
List<int> _dayBounds(int year) {
  final out = <int>[];
  for (
    var d = DateTime(year);
    d.year == year;
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    out.add(d.millisecondsSinceEpoch);
  }
  out.add(DateTime(year + 1).millisecondsSinceEpoch);
  return out;
}
