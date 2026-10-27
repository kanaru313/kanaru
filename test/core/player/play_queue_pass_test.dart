import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/play_queue.dart';
import 'package:kanaru/core/player/play_queue_pass.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/track.dart';

List<Track> _tracks(int count) => [
  for (var i = 0; i < count; i++) Track.fromPath('/music/$i.mp3'),
];

PlayQueue _onLast(int count, {bool shuffled = false}) {
  final queue = PlayQueue(
    original: _tracks(count),
    index: count - 1,
    repeat: RepeatMode.allShuffled,
  );
  return shuffled ? queue.shuffle(Random(1)).copyWith(index: count - 1) : queue;
}

void main() {
  group('endsShuffledPass', () {
    test('only on the last track under repeat all shuffled', () {
      expect(_onLast(3).endsShuffledPass, isTrue);
      expect(_onLast(3).copyWith(index: 1).endsShuffledPass, isFalse);
      expect(
        _onLast(3).copyWith(repeat: RepeatMode.all).endsShuffledPass,
        isFalse,
      );
      expect(
        PlayQueue(repeat: RepeatMode.allShuffled).endsShuffledPass,
        isFalse,
      );
    });

    test('the engine is handed nothing there, the next index is 0', () {
      final queue = _onLast(3);
      expect(queue.engineNextIndex, isNull);
      expect(queue.nextIndex, 0);
      expect(queue.copyWith(index: 0).engineNextIndex, 1);
      expect(
        queue.copyWith(repeat: RepeatMode.all).engineNextIndex,
        0,
        reason: 'plain repeat all still hands the first track',
      );
    });
  });

  group('nextShuffledPass', () {
    for (final count in [2, 3, 5]) {
      test('$count tracks: every track once, from index 0', () {
        for (var seed = 0; seed < 20; seed++) {
          final queue = _onLast(count);
          final next = queue.nextShuffledPass(Random(seed));

          expect(next.order.toList()..sort(), queue.order.toList()..sort());
          expect(next.index, 0);
          expect(next.shuffled, isTrue);
          expect(next.repeat, RepeatMode.allShuffled);
          expect(next.order.first, isNot(queue.order[queue.index]));
        }
      });
    }

    test('one track: the same queue, shuffle flag untouched', () {
      final queue = _onLast(1);
      final next = queue.nextShuffledPass(Random(1));

      expect(next, same(queue));
      expect(next.index, 0);
      expect(next.shuffled, isFalse);
      expect(next.unshuffledOrder, isNull);
    });

    test('an unshuffled queue keeps its order to go back to', () {
      final queue = _onLast(4);
      final next = queue.nextShuffledPass(Random(3));

      expect(next.unshuffledOrder, [0, 1, 2, 3]);
      expect(next.unshuffle().order, [0, 1, 2, 3]);
    });

    test('an already shuffled queue keeps the order it had', () {
      final queue = _onLast(5, shuffled: true);
      final before = queue.unshuffledOrder;
      final next = queue.nextShuffledPass(Random(4));

      expect(next.unshuffledOrder, before);
    });

    test('is deterministic for a seed and does not touch the original', () {
      final queue = _onLast(5);
      final a = queue.nextShuffledPass(Random(9));
      final b = queue.nextShuffledPass(Random(9));

      expect(a.order, b.order);
      expect(queue.order, [0, 1, 2, 3, 4]);
      expect(queue.shuffled, isFalse);
    });

    test('an empty queue stays as it is', () {
      final empty = PlayQueue(repeat: RepeatMode.allShuffled);
      expect(empty.nextShuffledPass(Random(1)), same(empty));
    });
  });
}
