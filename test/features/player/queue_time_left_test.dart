import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/play_queue.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/queue/queue_time_left.dart';

Track _t(int i, {Duration? duration}) =>
    Track(uri: '/m/$i.mp3', title: 't$i', duration: duration);

PlayQueue _queue(
  List<Duration?> durations, {
  int index = 0,
  RepeatMode repeat = RepeatMode.off,
}) => PlayQueue(
  original: [
    for (var i = 0; i < durations.length; i++) _t(i, duration: durations[i]),
  ],
  index: index,
  repeat: repeat,
);

void main() {
  Duration m(int n) => Duration(minutes: n);
  final min = m(1);

  group('queueTimeLeft', () {
    test('an empty queue has none', () {
      expect(queueTimeLeft(PlayQueue(), Duration.zero), isNull);
    });

    test('a single track is its length minus the position', () {
      final q = _queue([const Duration(minutes: 4)]);
      expect(queueTimeLeft(q, const Duration(minutes: 1)), m(3));
    });

    test('adds the tracks after the current one, not those before', () {
      final q = _queue([m(5), m(3), m(2), m(4)], index: 1);
      expect(queueTimeLeft(q, Duration.zero), m(9));
      expect(queueTimeLeft(q, min), m(8));
    });

    test('an unknown duration anywhere from the current one on hides it', () {
      expect(queueTimeLeft(_queue([min, null, min]), Duration.zero), isNull);
      expect(queueTimeLeft(_queue([min, min, null]), Duration.zero), isNull);
      expect(
        queueTimeLeft(_queue([null, min], index: 0), Duration.zero),
        isNull,
      );
    });

    test('an unknown duration before the current track does not matter', () {
      final q = _queue([null, m(2), m(3)], index: 1);
      expect(queueTimeLeft(q, Duration.zero), m(5));
    });

    test('repeat all and repeat one hide it', () {
      expect(
        queueTimeLeft(
          _queue([min, min], repeat: RepeatMode.all),
          Duration.zero,
        ),
        isNull,
      );
      expect(
        queueTimeLeft(
          _queue([min, min], repeat: RepeatMode.one),
          Duration.zero,
        ),
        isNull,
      );
    });

    test('a position past the duration never goes negative', () {
      final q = _queue([min, min]);
      expect(queueTimeLeft(q, m(5)), min);
      expect(queueTimeLeft(_queue([min]), m(5)), Duration.zero);
    });

    test('sums 50000 known durations', () {
      final q = _queue(List.filled(50000, min));
      expect(queueTimeLeft(q, Duration.zero), m(50000));
    });
  });

  test('ceilMinutes rounds up', () {
    expect(ceilMinutes(Duration.zero), 0);
    expect(ceilMinutes(const Duration(seconds: 1)), 1);
    expect(ceilMinutes(min), 1);
    expect(ceilMinutes(const Duration(minutes: 1, seconds: 1)), 2);
  });
}
