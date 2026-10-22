import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/history_rows.dart';
import 'package:kanaru/features/history/history_day_row_cache.dart';

HistoryPlayRow _row(int id) =>
    HistoryPlayRow(id: id, path: '/m/$id.flac', playedAt: id);

/// A loader whose reads wait for the test.
class _Reads {
  final started = <int>[];
  final _gates = <int, List<Completer<List<HistoryPlayRow>>>>{};

  Future<List<HistoryPlayRow>> load(int day) {
    started.add(day);
    final gate = Completer<List<HistoryPlayRow>>();
    (_gates[day] ??= []).add(gate);
    return gate.future;
  }

  void finish(int day, List<HistoryPlayRow> rows) =>
      _gates[day]!.removeAt(0).complete(rows);

  void fail(int day) => _gates[day]!.removeAt(0).completeError(StateError('x'));
}

void main() {
  late _Reads reads;
  late int changed;
  late DateTime clock;
  late HistoryDayRowCache cache;

  HistoryDayRowCache make({int maxDays = 40}) => HistoryDayRowCache(
    load: reads.load,
    onChanged: () => changed++,
    maxDays: maxDays,
    now: () => clock,
  );

  setUp(() {
    reads = _Reads();
    changed = 0;
    clock = DateTime(2026);
    cache = make();
  });

  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test('a day is unread until its read ends, then served', () async {
    expect(cache.rowsOf(1), isNull);
    reads.finish(1, [_row(10)]);
    await tick();

    expect(cache.rowsOf(1)!.single.id, 10);
    expect(changed, 1);
    // Fresh: asking again starts no read.
    expect(reads.started, [1]);
  });

  test('at most two reads run at once, the newest request first', () async {
    for (final day in [1, 2, 3, 4]) {
      cache.rowsOf(day);
    }
    expect(reads.started, [1, 2]);
    expect(cache.reading, 2);

    reads.finish(1, []);
    await tick();
    // 3 and 4 wait; the later request (4) goes first.
    expect(reads.started, [1, 2, 4]);
    reads.finish(2, []);
    await tick();
    expect(reads.started, [1, 2, 4, 3]);
  });

  test('a waiting day nobody asks for any more is skipped', () async {
    cache.rowsOf(1);
    cache.rowsOf(2);
    cache.rowsOf(3);
    clock = clock.add(const Duration(milliseconds: 400));
    cache.rowsOf(4);
    expect(reads.started, [1, 2]);

    reads.finish(1, []);
    await tick();
    // 3 went stale in the queue; 4 was just asked for.
    expect(reads.started, [1, 2, 4]);
  });

  test('asking again moves a waiting day to the front', () async {
    for (final day in [1, 2, 3, 4]) {
      cache.rowsOf(day);
    }
    cache.rowsOf(3);
    reads.finish(1, []);
    await tick();

    expect(reads.started.last, 3);
  });

  test('the least recently asked day goes first when full', () async {
    cache = make(maxDays: 2);
    for (final day in [1, 2]) {
      cache.rowsOf(day);
    }
    reads.finish(1, [_row(1)]);
    reads.finish(2, [_row(2)]);
    await tick();
    // Day 1 was asked for last: day 2 is the one to go.
    cache.rowsOf(1);
    cache.rowsOf(3);
    reads.finish(3, [_row(3)]);
    await tick();

    expect(cache.length, 2);
    expect(cache.rowsOf(1), isNotNull);
    expect(cache.rowsOf(3), isNotNull);
    expect(cache.rowsOf(2), isNull);
  });

  test(
    'a new version keeps the old rows until the day is read again',
    () async {
      cache.rowsOf(1);
      reads.finish(1, [_row(10)]);
      await tick();

      cache.invalidate();
      final stale = cache.rowsOf(1);
      expect(stale!.single.id, 10);
      expect(reads.started, [1, 1]);

      reads.finish(1, [_row(11), _row(10)]);
      await tick();
      expect(cache.rowsOf(1)!.map((r) => r.id), [11, 10]);
    },
  );

  test('a read from an older version is dropped when it ends', () async {
    cache.rowsOf(1);
    cache.invalidate();
    cache.rowsOf(1);
    // Two reads of day 1 are out: the old one ends first.
    reads.finish(1, [_row(1)]);
    await tick();
    expect(changed, 0);
    expect(cache.rowsOf(1), isNull);

    reads.finish(1, [_row(2)]);
    await tick();
    expect(cache.rowsOf(1)!.single.id, 2);
  });

  test('a failed read is asked for again on the next draw', () async {
    cache.rowsOf(1);
    reads.fail(1);
    await tick();
    expect(cache.rowsOf(1), isNull);

    expect(reads.started, [1, 1]);
  });

  test('a disposed cache serves nothing and starts nothing', () async {
    cache.rowsOf(1);
    cache.dispose();
    reads.finish(1, [_row(1)]);
    await tick();

    expect(changed, 0);
    expect(cache.rowsOf(1), isNull);
    expect(reads.started, [1]);
  });
}
