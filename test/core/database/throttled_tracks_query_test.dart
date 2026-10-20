import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/throttled_tracks_query.dart';

/// A load whose calls a test finishes by hand, counting overlaps.
class _Loads {
  final pending = <Completer<int>>[];
  final startedAt = <Duration>[];
  final endedAt = <Duration>[];
  final clock = Stopwatch()..start();
  var running = 0;
  var maxRunning = 0;
  var calls = 0;

  /// When set, each load finishes by itself after this long.
  Duration? autoFinish;

  Future<int> call() async {
    final n = ++calls;
    startedAt.add(clock.elapsed);
    running++;
    maxRunning = running > maxRunning ? running : maxRunning;
    try {
      final auto = autoFinish;
      if (auto != null) {
        await Future<void>.delayed(auto);
        return n;
      }
      final done = Completer<int>();
      pending.add(done);
      return await done.future;
    } finally {
      running--;
      endedAt.add(clock.elapsed);
    }
  }

  void finish() => pending.removeAt(0).complete(calls);
  void fail() => pending.removeAt(0).completeError(StateError('boom'));
}

void main() {
  late LibraryDatabase db;
  late _Loads loads;

  setUp(() {
    db = LibraryDatabase(NativeDatabase.memory());
    loads = _Loads();
  });
  tearDown(() => db.close());

  Future<void> changed() async {
    db.markTablesUpdated({db.tracks});
    await pumpEventQueue();
  }

  Stream<int> query(Duration interval) =>
      throttledTracksQuery(db, loads.call, interval: interval);

  test('loads when listened to and never runs two loads at once', () async {
    loads.autoFinish = const Duration(milliseconds: 60);
    final values = <int>[];
    final sub = query(const Duration(milliseconds: 10)).listen(values.add);
    for (var i = 0; i < 20; i++) {
      await changed();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await sub.cancel();

    expect(loads.maxRunning, 1);
    expect(values.first, 1);
    expect(loads.calls, lessThan(8), reason: 'updates during a load merge');
  });

  test('many changes during a load give exactly one more load', () async {
    final values = <int>[];
    final sub = query(Duration.zero).listen(values.add);
    await pumpEventQueue();
    expect(loads.calls, 1);
    for (var i = 0; i < 5; i++) {
      await changed();
    }
    loads.finish();
    await pumpEventQueue();
    expect(loads.calls, 2, reason: 'interval 0 reloads right after');
    loads.finish();
    await pumpEventQueue();
    expect(loads.calls, 2);
    expect(values, [1, 2]);
    await sub.cancel();
  });

  test('waits the interval from the end of the previous load', () async {
    const interval = Duration(milliseconds: 150);
    final sub = query(interval).listen((_) {});
    await pumpEventQueue();
    await changed();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    loads.finish();
    await pumpEventQueue();
    expect(loads.calls, 1, reason: 'still cooling down');

    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(loads.calls, 2);
    expect(
      loads.startedAt[1] - loads.endedAt[0],
      greaterThanOrEqualTo(interval),
    );
    loads.finish();
    await sub.cancel();
  });

  test('a failed load is an error and later changes load again', () async {
    final events = <Object>[];
    final sub = query(Duration.zero).listen(events.add, onError: events.add);
    await pumpEventQueue();
    loads.fail();
    await pumpEventQueue();
    expect(events.single, isStateError);

    await changed();
    loads.finish();
    await pumpEventQueue();
    expect(events.last, 2);
    await sub.cancel();
  });

  test('cancelling drops a late result and stops reloading', () async {
    final values = <int>[];
    final sub = query(const Duration(milliseconds: 20)).listen(values.add);
    await pumpEventQueue();
    await changed();
    await sub.cancel();
    loads.finish();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await changed();

    expect(values, isEmpty);
    expect(loads.calls, 1);
  });

  test(
    'does not load while paused; resuming after a change loads once',
    () async {
      final values = <int>[];
      final sub = query(Duration.zero).listen(values.add);
      await pumpEventQueue();
      loads.finish();
      await pumpEventQueue();

      sub.pause();
      await changed();
      await changed();
      expect(loads.calls, 1);

      sub.resume();
      await pumpEventQueue();
      expect(loads.calls, 2);
      loads.finish();
      await pumpEventQueue();
      expect(values, [1, 2]);

      sub.pause();
      sub.resume();
      await pumpEventQueue();
      expect(loads.calls, 2, reason: 'nothing changed while paused');
      await sub.cancel();
    },
  );
}
