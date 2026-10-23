import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/play_queue.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/track.dart';

List<Track> tracks(int count) => [
  for (var i = 0; i < count; i++) Track.fromPath('/music/$i.flac'),
];

void main() {
  test('names a track after its file without the extension', () {
    expect(Track.fromPath('/music/A Song.flac').title, 'A Song');
    expect(Track.fromPath('/music/.hidden').title, '.hidden');
  });

  test('opening at a start outside the tracks is a programming error', () {
    expect(() => PlayQueue.open(tracks(3), 3), throwsA(isA<AssertionError>()));
    expect(() => PlayQueue.open(tracks(3), -1), throwsA(isA<AssertionError>()));
  });

  group('next and previous', () {
    final five = tracks(5);

    test('move by one inside the queue', () {
      final queue = PlayQueue(original: five, index: 2);
      expect(queue.nextIndex, 3);
      expect(queue.previousIndex, 1);
    });

    test('stop at the edges with repeat off', () {
      expect(PlayQueue(original: five, index: 4).nextIndex, isNull);
      expect(PlayQueue(original: five).previousIndex, isNull);
    });

    test('wrap around with repeat all', () {
      final last = PlayQueue(original: five, index: 4, repeat: RepeatMode.all);
      expect(last.nextIndex, 0);
      expect(last.copyWith(index: 0).previousIndex, 4);
    });

    test('repeat one moves on manually but does not wrap', () {
      final queue = PlayQueue(original: five, index: 1, repeat: RepeatMode.one);
      expect(queue.nextIndex, 2);
      expect(queue.copyWith(index: 4).nextIndex, isNull);
      expect(queue.copyWith(index: 0).previousIndex, isNull);
    });

    test('do nothing on an empty queue', () {
      expect(PlayQueue().nextIndex, isNull);
      expect(PlayQueue().previousIndex, isNull);
      expect(PlayQueue().current, isNull);
    });
  });

  group('shuffle', () {
    final ten = tracks(10);

    test('puts the current track first and keeps every track', () {
      final queue = PlayQueue(original: ten, index: 6).shuffle(Random(1));

      expect(queue.shuffled, isTrue);
      expect(queue.index, 0);
      expect(queue.current, ten[6]);
      expect(queue.tracks.toSet(), ten.toSet());
      expect(queue.tracks, hasLength(10));
    });

    test('changes the order of the rest', () {
      final queue = PlayQueue(original: ten, index: 0).shuffle(Random(1));
      expect(queue.tracks, isNot(ten));
    });

    test('turning it off restores the order on the same track', () {
      final shuffled = PlayQueue(original: ten, index: 6).shuffle(Random(1));
      final moved = shuffled.copyWith(index: 3);
      final restored = moved.unshuffle();

      expect(restored.shuffled, isFalse);
      expect(restored.tracks, ten);
      expect(restored.current, moved.current);
    });

    test('finds the right copy when a file is queued twice', () {
      final song = Track.fromPath('/music/a.flac');
      final other = Track.fromPath('/music/b.flac');
      final queue = PlayQueue(original: [song, other, song], index: 2);

      final restored = queue.shuffle(Random(3)).unshuffle();
      expect(restored.index, 2);
    });

    test('opening shuffled starts with the chosen track', () {
      final queue = PlayQueue.open(ten, 4, shuffled: true, random: Random(2));
      expect(queue.current, ten[4]);
      expect(queue.index, 0);
    });

    test('keeps repeat', () {
      final queue = PlayQueue(original: ten, repeat: RepeatMode.one);
      expect(queue.shuffle(Random(1)).repeat, RepeatMode.one);
      expect(queue.shuffle(Random(1)).unshuffle().repeat, RepeatMode.one);
    });
  });

  group('move', () {
    final five = tracks(5);
    List<int> uris(PlayQueue q) => q.order;

    test(
      'a track from before the current one to after it shifts the index',
      () {
        final queue = PlayQueue(original: five, index: 2).move(0, 4);
        expect(uris(queue), [1, 2, 3, 4, 0]);
        expect(queue.index, 1);
        expect(queue.current, five[2]);
      },
    );

    test(
      'a track from after the current one to before it shifts the index',
      () {
        final queue = PlayQueue(original: five, index: 2).move(4, 0);
        expect(uris(queue), [4, 0, 1, 2, 3]);
        expect(queue.index, 3);
        expect(queue.current, five[2]);
      },
    );

    test('dragging the current track takes the index along', () {
      final queue = PlayQueue(original: five, index: 1).move(1, 3);
      expect(uris(queue), [0, 2, 3, 1, 4]);
      expect(queue.index, 3);
      expect(queue.current, five[1]);
    });

    test('moves that do not cross the current track keep the index', () {
      final queue = PlayQueue(original: five, index: 2).move(3, 4).move(0, 1);
      expect(queue.index, 2);
      expect(queue.current, five[2]);
    });

    test('ignores no-op and out-of-range moves', () {
      final queue = PlayQueue(original: five, index: 2);
      expect(queue.move(1, 1), same(queue));
      expect(queue.move(-1, 2), same(queue));
      expect(queue.move(0, 5), same(queue));
    });

    test('never touches original', () {
      final queue = PlayQueue(original: five).move(0, 3);
      expect(queue.original, same(five));
    });

    test('while shuffled leaves the order shuffle returns to alone', () {
      final shuffled = PlayQueue(original: five).shuffle(Random(1));
      final moved = shuffled.move(0, 2);
      expect(moved.unshuffledOrder, [0, 1, 2, 3, 4]);
    });
  });

  group('removeAt', () {
    final five = tracks(5);

    test('before the current track shifts the index down', () {
      final queue = PlayQueue(original: five, index: 3).removeAt(1);
      expect(queue.index, 2);
      expect(queue.current, five[3]);
      expect(queue.order, [0, 2, 3, 4]);
    });

    test('after the current track keeps the index', () {
      final queue = PlayQueue(original: five, index: 1).removeAt(3);
      expect(queue.index, 1);
      expect(queue.current, five[1]);
    });

    test('the current track lets the next one slide in', () {
      final queue = PlayQueue(original: five, index: 1).removeAt(1);
      expect(queue.index, 1);
      expect(queue.current, five[2]);
    });

    test('the last track goes to the new last, or the first on repeat all', () {
      final last = PlayQueue(original: five, index: 4);
      expect(last.removeAt(4).current, five[3]);
      expect(last.removeAt(4).index, 3);
      final all = last.copyWith(repeat: RepeatMode.all);
      expect(all.removeAt(4).index, 0);
    });

    test('the only track empties the queue and keeps original', () {
      final queue = PlayQueue(original: tracks(1)).removeAt(0);
      expect(queue.isEmpty, isTrue);
      expect(queue.current, isNull);
      expect(queue.index, 0);
      expect(queue.original, hasLength(1));
      expect(queue.nextIndex, isNull);
    });

    test('ignores an out-of-range position', () {
      final queue = PlayQueue(original: five);
      expect(queue.removeAt(5), same(queue));
      expect(queue.removeAt(-1), same(queue));
    });

    test('removes only the chosen copy of a file queued twice', () {
      final song = Track.fromPath('/music/a.flac');
      final other = Track.fromPath('/music/b.flac');
      final queue = PlayQueue(original: [song, other, song], index: 2);
      final edited = queue.removeAt(0);
      expect(edited.order, [1, 2]);
      expect(edited.current, song);
      expect(edited.index, 1);
    });

    test('drops the track from the order shuffle returns to', () {
      final shuffled = PlayQueue(original: five).shuffle(Random(1));
      final removed = shuffled.removeAt(2);
      expect(removed.unshuffledOrder, hasLength(4));
      expect(removed.unshuffledOrder!.toSet(), removed.order.toSet());
    });
  });

  group('keepOnlyCurrent', () {
    final five = tracks(5);

    test('keeps just the playing track', () {
      final queue = PlayQueue(original: five, index: 3).keepOnlyCurrent();
      expect(queue.order, [0]);
      expect(queue.index, 0);
      expect(queue.current, five[3]);
      expect(queue.original, [five[3]]);
    });

    test('while shuffled also resets the order shuffle returns to', () {
      final queue = PlayQueue(
        original: five,
        index: 3,
      ).shuffle(Random(1)).keepOnlyCurrent();
      expect(queue.shuffled, isTrue);
      expect(queue.unshuffledOrder, [0]);
      expect(queue.unshuffle().order, [0]);
    });

    test('does nothing to an empty queue', () {
      final empty = PlayQueue();
      expect(empty.keepOnlyCurrent(), same(empty));
    });
  });

  group('unshuffle after edits', () {
    final six = tracks(6);

    test('drops what was removed and keeps the current track', () {
      final shuffled = PlayQueue(original: six, index: 2).shuffle(Random(4));
      final removed = shuffled.removeAt(shuffled.order.indexOf(5));
      final restored = removed.unshuffle();
      expect(restored.order, [0, 1, 2, 3, 4]);
      expect(restored.current, six[2]);
    });

    test('loses the drag done while shuffled', () {
      final shuffled = PlayQueue(original: six).shuffle(Random(4));
      final dragged = shuffled.move(0, 5).move(1, 3);
      expect(dragged.unshuffle().order, [0, 1, 2, 3, 4, 5]);
    });

    test('keeps the drag done before shuffling', () {
      final dragged = PlayQueue(original: six).move(0, 5);
      final back = dragged.shuffle(Random(4)).unshuffle();
      expect(back.order, [1, 2, 3, 4, 5, 0]);
      expect(back.current, dragged.current);
    });

    test('falls back to the opened order without a saved one', () {
      final queue = PlayQueue(
        original: six,
        order: [3, 1, 2],
        index: 1,
        shuffled: true,
      );
      final restored = queue.unshuffle();
      expect(restored.order, [1, 2, 3]);
      expect(restored.current, six[1]);
    });

    test('order[index] stays put when another track is edited', () {
      final queue = PlayQueue(original: six, index: 3);
      final entry = queue.order[queue.index];
      for (final edited in [queue.removeAt(0), queue.move(5, 0)]) {
        expect(edited.order[edited.index], entry);
      }
    });
  });

  group('manual next and previous', () {
    final three = [
      for (final name in ['a', 'b', 'c']) Track.fromPath('/music/$name.mp3'),
    ];

    test('without wrap they match nextIndex and previousIndex', () {
      for (final repeat in RepeatMode.values) {
        for (var i = 0; i < 3; i++) {
          final queue = PlayQueue(original: three, index: i, repeat: repeat);
          expect(queue.manualNextIndex(wrap: false), queue.nextIndex);
          expect(queue.manualPreviousIndex(wrap: false), queue.previousIndex);
        }
      }
    });

    test('with wrap the ends meet whatever the repeat mode', () {
      for (final repeat in RepeatMode.values) {
        final last = PlayQueue(original: three, index: 2, repeat: repeat);
        expect(last.manualNextIndex(wrap: true), 0, reason: repeat.name);
        final first = PlayQueue(original: three, repeat: repeat);
        expect(first.manualPreviousIndex(wrap: true), 2, reason: repeat.name);
      }
    });

    test('with wrap the middle moves one step', () {
      final queue = PlayQueue(original: three, index: 1);
      expect(queue.manualNextIndex(wrap: true), 2);
      expect(queue.manualPreviousIndex(wrap: true), 0);
    });

    test('a one-track queue plays its track again', () {
      final queue = PlayQueue(original: [three.first]);
      expect(queue.manualNextIndex(wrap: true), 0);
      expect(queue.manualPreviousIndex(wrap: true), 0);
      expect(queue.manualNextIndex(wrap: false), isNull);
    });

    test('an empty queue goes nowhere', () {
      final queue = PlayQueue();
      expect(queue.manualNextIndex(wrap: true), isNull);
      expect(queue.manualPreviousIndex(wrap: true), isNull);
    });

    test('wrapping leaves nextIndex alone', () {
      final queue = PlayQueue(original: three, index: 2);
      queue.manualNextIndex(wrap: true);
      expect(queue.nextIndex, isNull);
    });
  });
}
