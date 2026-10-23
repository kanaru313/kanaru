import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/stats/listen_accumulator.dart';

Duration s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

/// Plays from [from] to [to] seconds in [step]-second ticks, position and
/// clock moving together.
void play(ListenAccumulator acc, num from, num to, {num step = 0.25}) {
  for (var t = from + step; t <= to + 1e-9; t += step) {
    acc.sample(position: s(t), clock: s(t), playing: true);
  }
}

ListenAccumulator fresh() => ListenAccumulator(
  position: Duration.zero,
  clock: Duration.zero,
  playing: true,
);

void main() {
  group('qualifiesAsListen', () {
    test('3:00 track needs 90 s', () {
      expect(qualifiesAsListen(s(89.75), s(180)), isFalse);
      expect(qualifiesAsListen(s(90), s(180)), isTrue);
    });

    test('long track is capped at 4 minutes', () {
      expect(qualifiesAsListen(s(239), s(600)), isFalse);
      expect(qualifiesAsListen(s(240), s(600)), isTrue);
    });

    test('30 s track never qualifies, 31 s track needs half', () {
      expect(qualifiesAsListen(s(30), s(30)), isFalse);
      expect(qualifiesAsListen(s(15.5), s(31)), isTrue);
      expect(qualifiesAsListen(s(15.4), s(31)), isFalse);
    });

    test('unknown length needs 4 minutes', () {
      expect(qualifiesAsListen(s(239), null), isFalse);
      expect(qualifiesAsListen(s(240), null), isTrue);
    });
  });

  group('ListenThreshold', () {
    const t2m25 = ListenThreshold(minutes: 2, percent: 25);

    test('the standard threshold is 4 minutes or half', () {
      expect(ListenThreshold.standard.requiredFor(s(180)), s(90));
      expect(ListenThreshold.standard.requiredFor(s(600)), s(240));
      expect(ListenThreshold.standard.requiredFor(null), s(240));
    });

    test('a custom share and length take the smaller', () {
      expect(qualifiesAsListen(s(44.75), s(180), t2m25), isFalse);
      expect(qualifiesAsListen(s(45), s(180), t2m25), isTrue);
      expect(qualifiesAsListen(s(119), s(1200), t2m25), isFalse);
      expect(qualifiesAsListen(s(120), s(1200), t2m25), isTrue);
    });

    test('an unknown length needs the minutes', () {
      expect(qualifiesAsListen(s(119), null, t2m25), isFalse);
      expect(qualifiesAsListen(s(120), null, t2m25), isTrue);
    });

    test('the whole track is reachable at 100 %', () {
      const whole = ListenThreshold(minutes: 10, percent: 100);
      // The last tick comes a moment before the end.
      expect(qualifiesAsListen(s(179.25), s(180), whole), isTrue);
      expect(qualifiesAsListen(s(178.75), s(180), whole), isFalse);
      // Longer than the minutes: the minutes win.
      expect(qualifiesAsListen(s(600), s(900), whole), isTrue);
    });

    test(
      'tracks of 30 seconds or less never count, whatever the threshold',
      () {
        const low = ListenThreshold(minutes: 1, percent: 10);
        expect(qualifiesAsListen(s(30), s(30), low), isFalse);
        expect(qualifiesAsListen(s(3.1), s(31), low), isTrue);
      },
    );
  });

  group('ListenAccumulator', () {
    test('counts ordinary ticks', () {
      final acc = fresh();
      play(acc, 0, 90);
      expect(acc.listened, s(90));
      play(acc, 90, 100, step: 1);
      expect(acc.listened, s(100));
    });

    test('a forward seek adds only the clock time', () {
      final acc = fresh();
      play(acc, 0, 10);
      acc.sample(position: s(70.1), clock: s(10.1), playing: true);
      expect(acc.listened, s(10.1));
    });

    test('a short forward seek over-counts by less than the slack', () {
      final acc = fresh();
      acc.sample(position: s(1), clock: s(0.1), playing: true);
      expect(acc.listened, s(1));
      acc.sample(position: s(1.9), clock: s(0.2), playing: true);
      expect(acc.listened, s(1.9));
    });

    test('a backward seek adds nothing and counting resumes there', () {
      final acc = fresh();
      play(acc, 0, 60);
      acc.sample(position: s(30), clock: s(60.1), playing: true);
      expect(acc.listened, s(60));
      acc.sample(position: s(30.25), clock: s(60.35), playing: true);
      expect(acc.listened, s(60.25));
    });

    test('paused samples add nothing and resume does not count the gap', () {
      final acc = fresh();
      play(acc, 0, 10);
      acc.sample(position: s(10), clock: s(10.1), playing: false);
      acc.sample(position: s(10), clock: s(610), playing: false);
      expect(acc.listened, s(10));
      acc.sample(position: s(10.25), clock: s(610.25), playing: true);
      // Sample before was paused: baseline only.
      expect(acc.listened, s(10));
      acc.sample(position: s(10.5), clock: s(610.5), playing: true);
      expect(acc.listened, s(10.25));
    });

    test('an engine stall adds only the position that advanced', () {
      final acc = fresh();
      acc.sample(position: s(0.1), clock: s(5), playing: true);
      expect(acc.listened, s(0.1));
    });

    test('a burst of late ticks after a UI stall counts in full', () {
      final acc = fresh();
      var position = 0.0;
      acc.sample(position: s(0), clock: s(2), playing: true);
      for (var i = 0; i < 8; i++) {
        position += 0.25;
        acc.sample(position: s(position), clock: s(2), playing: true);
      }
      expect(acc.listened, s(2));
    });

    test('a stale tick never adds more than real time', () {
      final acc = fresh();
      play(acc, 0, 10);
      acc.sample(position: s(9.8), clock: s(10.1), playing: true);
      acc.sample(position: s(10.25), clock: s(10.2), playing: true);
      expect(acc.listened, s(10.45));
    });

    test('counts from the baseline it was built with', () {
      final acc = ListenAccumulator(
        position: s(100),
        clock: s(5),
        playing: true,
      );
      acc.sample(position: s(100.25), clock: s(5.25), playing: true);
      expect(acc.listened, s(0.25));
    });

    test('built paused counts nothing until two playing samples', () {
      final acc = ListenAccumulator(
        position: s(100),
        clock: s(5),
        playing: false,
      );
      acc.sample(position: s(100.25), clock: s(5.25), playing: true);
      expect(acc.listened, Duration.zero);
      acc.sample(position: s(100.5), clock: s(5.5), playing: true);
      expect(acc.listened, s(0.25));
    });
  });
}
