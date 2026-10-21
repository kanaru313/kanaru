import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/play_queue.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/track.dart';

Track song(String name) => Track.fromPath('/music/$name.mp3');

List<String> titles(PlayQueue queue) => [for (final t in queue.tracks) t.title];

void main() {
  final abc = [song('a'), song('b'), song('c')];
  final x = song('x'), y = song('y');

  test('inserts after the current track and keeps it current', () {
    final queue = PlayQueue(original: abc).insert(1, [x, y]);

    expect(titles(queue), ['a', 'x', 'y', 'b', 'c']);
    expect(queue.current, abc[0]);
    expect(queue.original, [...abc, x, y]);
    expect(queue.order, [0, 3, 4, 1, 2]);
  });

  test('appends at the end', () {
    final queue = PlayQueue(original: abc, index: 2).insert(3, [x]);

    expect(titles(queue), ['a', 'b', 'c', 'x']);
    expect(queue.index, 2);
    expect(queue.nextIndex, 3);
  });

  test('inserting before the current track shifts its position', () {
    final queue = PlayQueue(original: abc, index: 1).insert(0, [x, y]);

    expect(titles(queue), ['x', 'y', 'a', 'b', 'c']);
    expect(queue.index, 3);
    expect(queue.current, abc[1]);
  });

  test('new entries never reuse a removed one', () {
    final queue = PlayQueue(original: abc).removeAt(2).insert(2, [x]);

    expect(queue.order, [0, 1, 3]);
    expect(queue.trackAt(2), x);
  });

  test('keeps repeat and ignores nothing or a bad position', () {
    final queue = PlayQueue(original: abc, repeat: RepeatMode.all);

    expect(queue.insert(1, [x]).repeat, RepeatMode.all);
    expect(queue.insert(1, const []), same(queue));
    expect(queue.insert(4, [x]), same(queue));
    expect(queue.insert(-1, [x]), same(queue));
  });

  test('inserts into an empty queue', () {
    final queue = PlayQueue().insert(0, [x, y]);

    expect(titles(queue), ['x', 'y']);
    expect(queue.index, 0);
  });

  group('while shuffled', () {
    final five = [for (final n in 'abcde'.split('')) song(n)];

    test(
      'plays at the given spot; unshuffling puts it after the same track',
      () {
        final shuffled = PlayQueue(original: five, index: 2).shuffle(Random(1));
        final current = shuffled.current;
        final inserted = shuffled.insert(shuffled.index + 1, [x]);

        expect(inserted.trackAt(inserted.index + 1), x);
        expect(inserted.current, current);

        final back = inserted.unshuffle();
        expect(titles(back), ['a', 'b', 'c', 'x', 'd', 'e']);
        expect(back.current, current);
      },
    );

    test('appended tracks end both orders', () {
      final shuffled = PlayQueue(original: five).shuffle(Random(2));
      final inserted = shuffled.insert(5, [x, y]);

      expect(titles(inserted).sublist(5), ['x', 'y']);
      expect(titles(inserted.unshuffle()), ['a', 'b', 'c', 'd', 'e', 'x', 'y']);
    });

    test('a second insert goes behind the first in the unshuffled order', () {
      final shuffled = PlayQueue(original: five, index: 1).shuffle(Random(3));
      final once = shuffled.insert(1, [x]);
      final twice = once.insert(2, [y]);

      expect(twice.trackAt(1), x);
      expect(twice.trackAt(2), y);
      expect(titles(twice.unshuffle()), ['a', 'b', 'x', 'y', 'c', 'd', 'e']);
    });
  });

  group('shuffle with kept tracks', () {
    final ten = [for (var i = 0; i < 10; i++) song('t$i')];

    test('the tracks after the current one stay put, the rest is shuffled', () {
      final queue = PlayQueue(original: ten, index: 4).shuffle(Random(1), 2);

      expect(queue.index, 0);
      expect(queue.order.sublist(0, 3), [4, 5, 6]);
      expect(queue.order.toSet(), {for (var i = 0; i < 10; i++) i});
      expect(queue.unshuffle().order, [for (var i = 0; i < 10; i++) i]);
    });

    test('more than there are is the rest of the queue', () {
      final queue = PlayQueue(original: abc).shuffle(Random(1), 9);

      expect(queue.order, [0, 1, 2]);
    });
  });

  group('keepOnlyCurrent', () {
    test('drops the added tracks from original too', () {
      final grown = PlayQueue(original: abc, index: 1).insert(3, [x, y]);
      final kept = grown.keepOnlyCurrent();

      expect(kept.original, [abc[1]]);
      expect(kept.order, [0]);
      expect(kept.insert(1, [x]).order, [0, 1]);
    });
  });

  group('invariants', () {
    test('a repeated or out-of-range entry is rejected', () {
      expect(
        () => PlayQueue(original: abc, order: [0, 0]),
        throwsAssertionError,
      );
      expect(
        () => PlayQueue(original: abc, order: [0, 3]),
        throwsAssertionError,
      );
      expect(
        () => PlayQueue(original: abc, order: [0, 1], unshuffledOrder: [0, 2]),
        throwsAssertionError,
      );
    });

    test('every change keeps them', () {
      var queue = PlayQueue(original: abc).insert(1, [x]);
      queue = queue.shuffle(Random(2), 1).insert(2, [y]).removeAt(3);
      queue = queue.move(0, 2).keepOnlyCurrent().insert(0, [x]);
      expect(queue.order.toSet().length, queue.order.length);
    });
  });
}
