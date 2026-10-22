import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' hide Track;
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/stats/listen_recorder.dart';
import 'package:logging/logging.dart';

import 'gated_query_interceptor.dart';
import 'listen_recorder_test_harness.dart';

const _insert = 'INTO "plays"';
const _update = 'UPDATE "plays"';

void main() {
  late LibraryDatabase db;
  late GatedQueryInterceptor gate;
  late FakeListenClock time;
  late ListenRecorder recorder;
  late PlayerSim sim;

  void build({bool enabled = true}) {
    recorder = ListenRecorder(db, enabled: enabled, clock: time.clock);
    sim = PlayerSim(recorder, time);
  }

  setUp(() async {
    (db, gate) = await openLibrary();
    time = FakeListenClock();
    build();
  });
  tearDown(() async {
    recorder.dispose();
    await recorder.idle;
    await db.close();
  });

  Future<List<Play>> plays() async {
    await recorder.idle;
    return (db.select(
      db.plays,
    )..orderBy([(p) => OrderingTerm.asc(p.id)])).get();
  }

  group('the listen rule', () {
    test('1:29 of 3:00 is not a listen, 1:30 is', () async {
      sim.open(trackA);
      sim.listen(89);
      expect(await plays(), isEmpty);
      final startedAt = time.now.subtract(const Duration(seconds: 89));

      sim.listen(1);

      final row = (await plays()).single;
      expect(row.path, trackA.uri);
      expect(row.playedAt, startedAt.millisecondsSinceEpoch);
      expect(row.listenedMs, 90000);
    });

    test('an unknown length needs 4:00', () async {
      sim.open(trackUnknown);
      sim.listen(239);
      expect(await plays(), isEmpty);
      sim.listen(1);
      expect(await plays(), hasLength(1));
    });

    test('a track of 25 s never counts', () async {
      sim.open(trackShort);
      sim.listen(25);
      sim.open(trackA);
      expect(await plays(), isEmpty);
    });

    test('a forward seek only adds the audio played before it', () async {
      sim.open(trackA);
      sim.listen(10);
      sim.seek(seconds(170));
      sim.listen(10);
      sim.stop();
      expect(await plays(), isEmpty);
    });

    test('seeking back to the start stays in the same play', () async {
      sim.open(trackA);
      final startedAt = time.now.millisecondsSinceEpoch;
      sim.listen(60);
      sim.seek(Duration.zero);
      sim.listen(40);

      final row = (await plays()).single;
      expect(row.playedAt, startedAt);
    });

    test('every loop of repeat one is its own play', () async {
      final first = time.now.millisecondsSinceEpoch;
      for (var loop = 0; loop < 3; loop++) {
        sim.open(trackLoop);
        sim.listen(40);
      }

      final rows = await plays();
      expect(rows, hasLength(3));
      expect(rows.map((r) => r.playedAt - first), [0, 40000, 80000]);
    });

    test('jumping to the same entry discards the time before it', () async {
      sim.open(trackA);
      sim.listen(60);
      sim.open(trackA);
      sim.listen(60);
      expect(await plays(), isEmpty);
    });

    test('changing track at 1:00 writes nothing for the first', () async {
      sim.open(trackA);
      sim.listen(60);
      sim.open(trackB);
      sim.listen(60);
      sim.open(trackA);
      sim.listen(90);

      final rows = await plays();
      expect(rows.map((r) => r.path), [trackA.uri]);
    });

    test('a restored paused track counts from the moment of play', () async {
      sim.open(trackA, play: false, at: seconds(90));
      sim.wait(const Duration(hours: 1));
      final playedAt = time.now.millisecondsSinceEpoch;
      sim.resume();
      sim.listen(89);
      expect(await plays(), isEmpty);
      sim.listen(1);

      final row = (await plays()).single;
      expect(row.playedAt, playedAt);
      expect(row.listenedMs, 90000);
    });

    test('stop ends the play; playing again is a new one', () async {
      sim.open(trackA);
      sim.listen(120);
      sim.stop();
      expect((await plays()).single.listenedMs, 120000);

      sim.resume();
      sim.listen(89);
      expect(await plays(), hasLength(1));
      sim.listen(1);
      expect(await plays(), hasLength(2));
    });

    test('a file URI of a library track is stored as the plain path', () async {
      sim.open(
        const Track(
          uri: 'file:///music/a.mp3',
          title: 'a',
          duration: Duration(minutes: 3),
        ),
      );
      sim.listen(90);

      expect((await plays()).single.path, '/music/a.mp3');
    });
  });

  group('only library tracks', () {
    test('one lookup for the whole playthrough, no insert', () async {
      sim.open(stranger);
      sim.listen(180);
      sim.open(trackA);

      expect(await plays(), isEmpty);
      expect(gate.count('FROM "tracks"'), 1);
      expect(gate.count(_insert), 0);
    });

    test('a file URI outside the library gets no row and no lookup', () async {
      sim.open(
        const Track(
          uri: 'file:///elsewhere/x.flac',
          title: 'x',
          duration: Duration(minutes: 3),
        ),
      );
      sim.listen(180);

      expect(await plays(), isEmpty);
    });
  });

  group('writes', () {
    test('a track change after the whole track updates the same row', () async {
      sim.open(trackA);
      sim.listen(180);
      sim.open(trackB);

      final row = (await plays()).single;
      expect(row.listenedMs, 180000);
    });

    test('a long listen is checkpointed every 30 s', () async {
      sim.open(trackB);
      sim.listen(240);
      await recorder.idle;
      gate.statements.clear();

      sim.listen(31);

      final row = (await plays()).single;
      expect(gate.count(_update), 1);
      expect(row.listenedMs, 270000);
    });

    test('a pause writes when 5 s are new, not for 2 s', () async {
      sim.open(trackA);
      sim.listen(100);
      sim.pause();
      expect((await plays()).single.listenedMs, 100000);
      expect(gate.count(_update), 1);

      sim.resume();
      sim.listen(2);
      sim.pause();
      await recorder.idle;
      expect(gate.count(_update), 1);
    });

    test('play/pause spam costs almost nothing', () async {
      sim.open(trackA);
      sim.listen(90);
      await recorder.idle;
      gate.statements.clear();

      for (var i = 0; i < 50; i++) {
        sim.pause();
        sim.resume();
        sim.listen(0.1, step: 0.1);
      }

      await recorder.idle;
      expect(gate.count(_update), lessThanOrEqualTo(2));
    });

    test('dispose writes the open play, then the recorder is inert', () async {
      sim.open(trackA);
      sim.listen(100);
      recorder.dispose();
      expect((await plays()).single.listenedMs, 100000);

      gate.statements.clear();
      sim.open(trackB);
      sim.listen(300);
      await recorder.idle;
      expect(gate.statements, isEmpty);
    });
  });

  group('flush', () {
    test('updates the listened time of a stored row', () async {
      sim.open(trackA);
      sim.listen(95);
      await recorder.idle;
      sim.listen(20);

      await recorder.flush();

      final row = (await plays()).single;
      expect(row.listenedMs, 115000);
    });

    test('keeps recording: the same row is updated, never a second', () async {
      sim.open(trackA);
      sim.listen(100);
      await recorder.flush();

      sim.listen(40);
      sim.open(trackB);
      final rows = await plays();

      expect(rows, hasLength(1));
      expect(rows.single.listenedMs, 140000);
    });

    test('writes nothing twice when nothing was listened since', () async {
      sim.open(trackA);
      sim.listen(100);
      await recorder.flush();
      gate.statements.clear();

      await recorder.flush();

      expect(gate.statements, isEmpty);
    });

    test('completes with nothing open', () async {
      await recorder.flush();
      sim.open(trackA);
      sim.stop();
      await recorder.flush();
      expect(await plays(), isEmpty);
    });

    test('writes nothing while recording is off', () async {
      sim.open(trackA);
      sim.listen(10);
      recorder.setEnabled(false);
      gate.statements.clear();

      await recorder.flush();

      expect(gate.statements, isEmpty);
    });

    test('writes nothing while the history is being cleared', () async {
      sim.open(trackA);
      sim.listen(100);
      await recorder.idle;
      final cleared = recorder.clearHistory();
      gate.statements.clear();

      await recorder.flush();
      await cleared;

      expect(gate.count(_update), 0);
      expect(await plays(), isEmpty);
    });
  });

  group('while the insert is still queued', () {
    // Holds the insert, listens 10 s more, then runs [boundary] in the same
    // synchronous run, so the row id is unknown when it happens.
    Future<void> boundaryDuringInsert(void Function() boundary) async {
      final release = gate.holdNext(_insert);
      sim.open(trackA);
      sim.listen(100);
      boundary();
      release();
    }

    final boundaries = <String, void Function(PlayerSim sim, ListenRecorder r)>{
      'next track': (s, _) => s.open(trackB),
      'pause': (s, _) => s.pause(),
      'stop': (s, _) => s.stop(),
      'switching off': (_, r) => r.setEnabled(false),
      'dispose': (_, r) => r.dispose(),
    };
    for (final entry in boundaries.entries) {
      test('${entry.key}: one row with the final time', () async {
        await boundaryDuringInsert(() => entry.value(sim, recorder));

        final row = (await plays()).single;
        expect(row.path, trackA.uri);
        expect(row.listenedMs, 100000);
      });
    }

    test('flush waits for the insert and ends with the flushed time', () async {
      final release = gate.holdNext(_insert);
      sim.open(trackA);
      sim.listen(100);
      sim.listen(5);

      var flushed = false;
      final flushing = recorder.flush().then((_) => flushed = true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(flushed, isFalse);

      release();
      await flushing;

      final row = (await plays()).single;
      expect(row.listenedMs, 105000);
    });

    test('clear: no row, and the next play can insert its own', () async {
      late Future<int?> cleared;
      await boundaryDuringInsert(() => cleared = recorder.clearHistory());

      expect(await cleared, anyOf(0, 1));
      expect(await plays(), isEmpty);
      expect(await db.select(db.playStats).get(), isEmpty);

      sim.listen(90);
      final row = (await plays()).single;
      expect(row.path, trackA.uri);
    });
  });

  group('track boundaries', () {
    test('the next file\'s duration under the old marker is ignored', () async {
      sim.open(trackB);
      sim.listen(230);
      // Gapless: the next file's length and first ticks arrive before the
      // player moves the marker.
      sim.duration = const Duration(minutes: 2);
      sim.position = Duration.zero;
      sim.emit();
      sim.listen(5);
      sim.open(trackC);
      expect(await plays(), isEmpty);

      sim.listen(60);
      expect((await plays()).single.path, trackC.uri);
    });

    test('the queue published ahead of the marker is ignored', () async {
      sim.open(trackUnknown);
      sim.listen(120);
      // New queue and its duration are visible, the marker is not bumped yet.
      sim.track = trackA;
      sim.duration = const Duration(minutes: 3);
      sim.emit();
      sim.open(trackA);

      expect(await plays(), isEmpty);
    });
  });

  group('the switch', () {
    test('off from the start records nothing', () async {
      build(enabled: false);
      sim.open(trackA);
      sim.listen(180);
      await recorder.idle;
      expect(gate.statements, isEmpty);
      expect(await plays(), isEmpty);
    });

    test('off before the threshold records nothing', () async {
      sim.open(trackA);
      sim.listen(60);
      recorder.setEnabled(false);
      sim.listen(120);
      expect(await plays(), isEmpty);
    });

    test('off after the insert keeps the time so far and stops', () async {
      sim.open(trackA);
      sim.listen(100);
      recorder.setEnabled(false);
      expect((await plays()).single.listenedMs, 100000);

      gate.statements.clear();
      sim.listen(20);
      recorder.setEnabled(true);
      sim.listen(60);
      await recorder.idle;
      expect(gate.statements, isEmpty);
      expect(await plays(), hasLength(1));
    });

    test('on again counts from then, dated at that moment', () async {
      sim.open(trackB);
      recorder.setEnabled(false);
      sim.listen(300);
      final enabledAt = time.now.millisecondsSinceEpoch;
      recorder.setEnabled(true);
      sim.listen(239);
      expect(await plays(), isEmpty);
      sim.listen(1);

      expect((await plays()).single.playedAt, enabledAt);
    });

    test('on again after a counted play is not a second play', () async {
      sim.open(trackB);
      sim.listen(240);
      expect(await plays(), hasLength(1));

      recorder.setEnabled(false);
      recorder.setEnabled(true);
      sim.listen(240);

      final row = (await plays()).single;
      expect(row.listenedMs, 240000);
    });

    test('on again while the insert is queued is not a second play', () async {
      final release = gate.holdNext(_insert);
      sim.open(trackB);
      sim.listen(240);
      recorder.setEnabled(false);
      recorder.setEnabled(true);
      sim.listen(240);
      release();

      expect(await plays(), hasLength(1));
    });

    test('after being counted, the next fresh start counts again', () async {
      sim.open(trackB);
      sim.listen(240);
      recorder.setEnabled(false);
      recorder.setEnabled(true);

      sim.open(trackA);
      sim.listen(90);

      expect(await plays(), hasLength(2));
    });

    test('off and on in a replay counts the replay on its own', () async {
      sim.open(trackB);
      sim.listen(240);
      sim.stop();
      sim.resume();
      sim.listen(60);

      recorder.setEnabled(false);
      recorder.setEnabled(true);
      sim.listen(240);

      expect(await plays(), hasLength(2));
    });

    test(
      'a stop and replay while off is counted after the switch on',
      () async {
        sim.open(trackA);
        sim.listen(100);
        recorder.setEnabled(false);
        sim.stop();
        sim.resume();
        recorder.setEnabled(true);
        sim.listen(90);

        expect(await plays(), hasLength(2));
      },
    );

    test('stop and play after the switch counts the track again', () async {
      sim.open(trackA);
      sim.listen(100);
      recorder.setEnabled(false);
      recorder.setEnabled(true);
      sim.stop();
      sim.resume();
      sim.listen(90);

      expect(await plays(), hasLength(2));
    });
  });

  group('clearing', () {
    test('with a row open: empties, never recreates, counts anew', () async {
      sim.open(trackA);
      sim.listen(100);
      final oldId = (await plays()).single.id;

      expect(await recorder.clearHistory(), 1);
      expect(await plays(), isEmpty);
      expect(await db.select(db.playStats).get(), isEmpty);

      sim.listen(50);
      expect(await plays(), isEmpty);
      sim.listen(40);
      final row = (await plays()).single;
      expect(row.id, isNot(oldId));
    });

    test('while recording is off: deletes, starts nothing', () async {
      sim.open(trackA);
      sim.listen(100);
      recorder.setEnabled(false);
      await recorder.idle;

      expect(await recorder.clearHistory(), 1);
      sim.listen(80);
      expect(await plays(), isEmpty);

      recorder.setEnabled(true);
      sim.listen(90);
      expect(await plays(), hasLength(1));
    });

    test('a failing delete returns null, not 0', () async {
      sim.open(trackA);
      sim.listen(100);
      await recorder.idle;

      gate.failNext('DELETE FROM');
      expect(await recorder.clearHistory(), isNull);
      expect(await plays(), hasLength(1));
    });

    test('after a switch back on, the counted play counts anew', () async {
      sim.open(trackB);
      sim.listen(240);
      recorder.setEnabled(false);
      recorder.setEnabled(true);

      expect(await recorder.clearHistory(), 1);
      sim.listen(239);
      expect(await plays(), isEmpty);
      sim.listen(1);

      expect(await plays(), hasLength(1));
    });

    test('a failing delete keeps the open play counting', () async {
      sim.open(trackA);
      sim.listen(60);

      gate.failNext('DELETE FROM');
      expect(await recorder.clearHistory(), isNull);
      sim.listen(30);

      expect((await plays()).single.listenedMs, 90000);
    });

    test('a failing delete keeps the time heard while it ran', () async {
      sim.open(trackA);
      sim.listen(60);

      gate.failNext('DELETE FROM');
      final cleared = recorder.clearHistory();
      sim.listen(30);
      expect(await cleared, isNull);
      sim.listen(1);
      recorder.dispose();

      expect((await plays()).single.listenedMs, 91000);
    });

    test('a failing delete keeps a row already stored', () async {
      sim.open(trackA);
      sim.listen(100);
      await recorder.idle;

      gate.failNext('DELETE FROM');
      expect(await recorder.clearHistory(), isNull);
      sim.listen(20);
      recorder.dispose();

      expect((await plays()).single.listenedMs, 120000);
    });

    test(
      'a failing delete under a long wait counts the sitting once',
      () async {
        sim.open(trackA);
        sim.listen(100);
        await recorder.idle;

        gate.failNext('DELETE FROM');
        final cleared = recorder.clearHistory();
        sim.listen(90);
        expect(await cleared, isNull);
        sim.listen(1);
        recorder.dispose();

        expect((await plays()).single.listenedMs, 191000);
      },
    );

    test(
      'nothing is counted while the delete runs, then it counts anew',
      () async {
        sim.open(trackA);
        sim.listen(100);
        await recorder.idle;

        final release = gate.holdNext('DELETE FROM');
        final cleared = recorder.clearHistory();
        sim.listen(100);
        release();
        expect(await cleared, 1);
        expect(await plays(), isEmpty);

        sim.listen(89);
        expect(await plays(), isEmpty);
        sim.listen(1);
        expect(await plays(), hasLength(1));
      },
    );

    test(
      'dispose while the delete runs still deletes and writes nothing',
      () async {
        sim.open(trackA);
        sim.listen(100);
        await recorder.idle;

        final release = gate.holdNext('DELETE FROM');
        final cleared = recorder.clearHistory();
        recorder.dispose();
        release();

        expect(await cleared, 1);
        expect(await plays(), isEmpty);
      },
    );

    test(
      'off during a failing delete, then on, is not a second play',
      () async {
        sim.open(trackA);
        sim.listen(100);
        await recorder.idle;

        gate.failNext('DELETE FROM');
        final cleared = recorder.clearHistory();
        recorder.setEnabled(false);
        expect(await cleared, isNull);
        recorder.setEnabled(true);
        sim.listen(90);

        expect(await plays(), hasLength(1));
      },
    );
  });

  group('failures', () {
    late List<LogRecord> logs;
    late StreamSubscription<LogRecord> subscription;
    late Level previousLevel;

    setUp(() {
      logs = [];
      previousLevel = Logger.root.level;
      Logger.root.level = Level.ALL;
      subscription = Logger.root.onRecord
          .where((r) => r.loggerName == 'listen_recorder')
          .listen(logs.add);
    });
    tearDown(() {
      Logger.root.level = previousLevel;
      return subscription.cancel();
    });

    test('a failed insert ends that play only; the next one writes', () async {
      gate.failNext(_insert);
      sim.open(trackA);
      sim.listen(120);
      expect(await plays(), isEmpty);
      expect(logs, hasLength(1));

      sim.open(trackA);
      sim.listen(90);
      expect(await plays(), hasLength(1));
    });

    test('a closed database never throws or leaks the path', () async {
      await db.close();
      sim.open(trackA);
      final playedAt = time.now.millisecondsSinceEpoch;
      sim.listen(100);
      sim.open(trackB);
      await recorder.idle;

      expect(logs, isNotEmpty);
      for (final record in logs) {
        expect(record.error, isNull);
        final text = '${record.message} ${record.stackTrace}';
        expect(text, isNot(contains(trackA.uri)));
        expect(text, isNot(contains('$playedAt')));
      }
    });
  });
}
