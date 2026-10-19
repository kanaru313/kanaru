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
}
