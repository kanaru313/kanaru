import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/translation_prefetch_window.dart';
import 'package:kanaru/core/player/play_queue.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/track.dart';

Track _t(String name) => Track(uri: '/m/$name.mp3', title: name);

List<String> _names(List<Track> tracks) => [for (final t in tracks) t.title];

PlayQueue _queue(
  List<String> names, {
  int index = 0,
  RepeatMode repeat = RepeatMode.off,
}) => PlayQueue(
  original: [for (final n in names) _t(n)],
  index: index,
  repeat: repeat,
);

void main() {
  test('takes the next tracks in play order', () {
    final q = _queue(['a', 'b', 'c', 'd'], index: 1);
    expect(_names(prefetchWindow(q, 2)), ['c', 'd']);
  });

  test('zero or an empty queue gives nothing', () {
    expect(prefetchWindow(_queue(['a', 'b']), 0), isEmpty);
    expect(prefetchWindow(PlayQueue(), 3), isEmpty);
  });

  test('stops at the end of the queue without repeat and with a '
      'shuffled repeat', () {
    for (final repeat in [RepeatMode.off, RepeatMode.allShuffled]) {
      final q = _queue(['a', 'b', 'c'], index: 1, repeat: repeat);
      expect(_names(prefetchWindow(q, 5)), ['c'], reason: '$repeat');
    }
  });

  test('repeat one has no window', () {
    final q = _queue(
      ['a', 'b', 'c', 'd', 'e'],
      index: 2,
      repeat: RepeatMode.one,
    );
    expect(prefetchWindow(q, 3), isEmpty);
  });

  test('wraps to the start under repeat all and stops before the current '
      'track', () {
    final q = _queue(['a', 'b', 'c'], index: 1, repeat: RepeatMode.all);
    expect(_names(prefetchWindow(q, 2)), ['c', 'a']);
    expect(_names(prefetchWindow(q, 9)), ['c', 'a']);
  });

  test('follows the shuffled order, not the opened one', () {
    final q = PlayQueue(
      original: [
        for (final n in ['a', 'b', 'c']) _t(n),
      ],
      order: [2, 0, 1],
      index: 0,
      shuffled: true,
    );
    expect(_names(prefetchWindow(q, 2)), ['a', 'b']);
  });

  test('leaves out repeated uris and the playing uri', () {
    final q = PlayQueue(
      original: [_t('a'), _t('b'), _t('a'), _t('b'), _t('c')],
    );
    expect(_names(prefetchWindow(q, 3)), ['b', 'c']);
  });

  test('a single track has no window, even under repeat all', () {
    expect(prefetchWindow(_queue(['a'], repeat: RepeatMode.all), 3), isEmpty);
  });
}
