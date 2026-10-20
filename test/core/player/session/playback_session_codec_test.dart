import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/session/playback_session.dart';
import 'package:kanaru/core/player/session/playback_session_codec.dart';
import 'package:kanaru/core/player/track.dart';

void main() {
  const a = Track(
    uri: '/music/a.flac',
    title: 'A',
    artist: 'X',
    artUri: '/covers/a.jpg',
    duration: Duration(minutes: 3, seconds: 35),
  );
  const b = Track(uri: '/music/b.flac', title: 'B');
  const c = Track(uri: '/music/c.flac', title: 'C');

  PlaybackSession roundTrip(PlaybackSession session) => decodePlaybackSession(
    jsonDecode(jsonEncode(encodePlaybackSession(session)))
        as Map<String, Object?>,
  );

  Map<String, Object?> valid() => jsonDecode(
    jsonEncode(
      encodePlaybackSession(
        const PlaybackSession(
          tracks: [a, b, c],
          order: [0, 2, 1],
          unshuffledOrder: [0, 1, 2],
          index: 1,
          shuffled: true,
          repeat: RepeatMode.all,
          position: Duration(seconds: 83),
          volume: 70,
        ),
      ),
    ),
  ) as Map<String, Object?>;

  group('round trip', () {
    test('a plain queue', () {
      const session = PlaybackSession(
        tracks: [a, b, c],
        order: [0, 1, 2],
        index: 2,
        position: Duration(milliseconds: 1234),
        volume: 55.5,
      );
      final back = roundTrip(session);

      expect(back, session);
      expect(back.tracks.first.artist, 'X');
      expect(back.tracks.first.artUri, '/covers/a.jpg');
      expect(back.tracks.first.duration, a.duration);
    });

    test('a shuffled queue keeps both orders', () {
      final back = roundTrip(decodePlaybackSession(valid()));

      expect(back.order, [0, 2, 1]);
      expect(back.unshuffledOrder, [0, 1, 2]);
      expect(back.shuffled, isTrue);
      expect(back.repeat, RepeatMode.all);
      expect(back.position, const Duration(seconds: 83));
    });

    test('repeat one and mute', () {
      const session = PlaybackSession(
        tracks: [a],
        order: [0],
        repeat: RepeatMode.one,
        volume: 0,
        volumeBeforeMute: 40,
      );

      expect(roundTrip(session), session);
    });

    test('an empty queue keeps volume, shuffle and repeat', () {
      const session = PlaybackSession(
        shuffled: true,
        repeat: RepeatMode.all,
        volume: 20,
      );
      final back = roundTrip(session);

      expect(back, session);
      expect(back.hasTrack, isFalse);
      expect(back.toQueue().isEmpty, isTrue);
    });

    test('removed tracks stay in tracks, not in order', () {
      const session = PlaybackSession(tracks: [a, b, c], order: [2, 0]);

      expect(roundTrip(session).toQueue().tracks, [c, a]);
    });
  });

  test('ignores unknown keys and optional track fields', () {
    final json = valid()
      ..['future'] = {'x': 1}
      ..['tracks'] = [
        {'uri': '/music/a.flac', 'title': 'A'},
        {'uri': '/music/b.flac', 'title': 'B', 'extra': true},
        {'uri': '/music/c.flac', 'title': 'C', 'artist': null},
      ];
    final session = decodePlaybackSession(json);

    expect(session.tracks.map((t) => t.uri), [a.uri, b.uri, c.uri]);
    expect(session.tracks.first.duration, isNull);
  });

  test('clamps the volume into 0–100', () {
    final json = valid()
      ..['volume'] = 150
      ..['volumeBeforeMute'] = -3;
    final session = decodePlaybackSession(json);

    expect(session.volume, 100);
    expect(session.volumeBeforeMute, 0);
  });

  test('an empty order ignores the index', () {
    final json = valid()
      ..['order'] = <int>[]
      ..['unshuffledOrder'] = null
      ..['index'] = 5;

    expect(decodePlaybackSession(json).index, 0);
  });

  group('rejects', () {
    final cases = <String, void Function(Map<String, Object?>)>{
      'tracks that are not a list': (j) => j['tracks'] = 'x',
      'a track without uri': (j) => j['tracks'] = [
        {'title': 'A'},
        {'uri': 'b', 'title': 'B'},
        {'uri': 'c', 'title': 'C'},
      ],
      'a track with an empty uri': (j) =>
          (j['tracks'] as List)[0] = {'uri': '', 'title': 'A'},
      'a track without title': (j) => (j['tracks'] as List)[0] = {'uri': 'a'},
      'a negative track duration': (j) => (j['tracks'] as List)[0] = {
        'uri': 'a',
        'title': 'A',
        'durationMs': -1,
      },
      'a missing order': (j) => j.remove('order'),
      'order with a non-int': (j) => j['order'] = [0, '1', 2],
      'order out of range': (j) => j['order'] = [0, 3, 1],
      'order with a duplicate': (j) => j['order'] = [0, 0, 1],
      'index out of range': (j) => j['index'] = 3,
      'a negative index': (j) => j['index'] = -1,
      'unshuffledOrder of other entries': (j) =>
          j['unshuffledOrder'] = [0, 1, 1],
      'unshuffledOrder of another length': (j) => j['unshuffledOrder'] = [0, 1],
      'an unknown repeat mode': (j) => j['repeat'] = 'sometimes',
      'shuffled that is not a bool': (j) => j['shuffled'] = 1,
      'a negative position': (j) => j['positionMs'] = -5,
      'a fractional position': (j) => j['positionMs'] = 1.5,
      'a missing volume': (j) => j.remove('volume'),
      'a volume that is not a number': (j) => j['volume'] = 'loud',
      'a volumeBeforeMute that is not a number': (j) =>
          j['volumeBeforeMute'] = true,
    };
    for (final MapEntry(key: name, value: edit) in cases.entries) {
      test(name, () {
        final json = valid();
        edit(json);

        expect(() => decodePlaybackSession(json), throwsFormatException);
      });
    }
  });

  test('reads the version', () {
    expect(playbackSessionVersionOf(valid()), playbackSessionVersion);
    expect(playbackSessionVersionOf({'version': 2}), 2);
    expect(playbackSessionVersionOf({'version': 0}), isNull);
    expect(playbackSessionVersionOf({'version': '1'}), isNull);
    expect(playbackSessionVersionOf({}), isNull);
  });

  test('encodes and decodes a 5000-track session quickly', () {
    final tracks = [
      for (var i = 0; i < 5000; i++)
        Track(
          uri: '/home/user/Music/Artist $i/Album $i/$i - Some title.flac',
          title: 'Some title $i',
          artist: 'Artist $i',
          duration: Duration(seconds: 200 + i % 100),
        ),
    ];
    final session = PlaybackSession(
      tracks: tracks,
      order: [for (var i = 4999; i >= 0; i--) i],
      unshuffledOrder: [for (var i = 0; i < 5000; i++) i],
      shuffled: true,
      index: 1234,
    );
    // Best of a few runs: the first one pays for the JIT, and other test
    // files running in parallel slow down any single run.
    var encodeTime = const Duration(days: 1);
    var decodeTime = const Duration(days: 1);
    late PlaybackSession back;
    for (var run = 0; run < 5; run++) {
      final watch = Stopwatch()..start();
      final text = jsonEncode(encodePlaybackSession(session));
      if (watch.elapsed < encodeTime) encodeTime = watch.elapsed;
      watch.reset();
      back = decodePlaybackSession(jsonDecode(text) as Map<String, Object?>);
      if (watch.elapsed < decodeTime) decodeTime = watch.elapsed;
    }

    expect(back, session);
    // A debug-mode test on a busy machine, so the bound is loose: it catches
    // a codec that grows worse than linear, not a few milliseconds.
    const budget = Duration(milliseconds: 250);
    expect(encodeTime, lessThan(budget));
    expect(decodeTime, lessThan(budget));
  });
}
