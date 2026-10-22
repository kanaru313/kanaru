import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/session/playback_session.dart';
import 'package:kanaru/core/player/session/playback_session_codec.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:logging/logging.dart';

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

  group('uris that are not local audio files', () {
    const bad = [
      'http://example.test/a.mp3',
      'edl://%5,/music/a.flac',
      'av://lavfi:sine=frequency=440',
      'file:///music/a.flac',
      'a.flac',
      '/music/notes.txt',
      '/music/a\u0000.flac',
    ];

    /// A session of tracks at [uris] (the first track is the current one
    /// unless [order]/[index] say otherwise).
    Map<String, Object?> sessionOf(
      List<String> uris, {
      List<int>? order,
      List<int>? unshuffled,
      int index = 0,
      int positionMs = 5000,
    }) {
      final json = valid();
      json['tracks'] = [
        for (var i = 0; i < uris.length; i++)
          {'uri': uris[i], 'title': 't$i', 'artist': null, 'durationMs': null},
      ];
      json['order'] = order ?? [for (var i = 0; i < uris.length; i++) i];
      json['unshuffledOrder'] = unshuffled;
      json['index'] = index;
      json['positionMs'] = positionMs;
      return json;
    }

    List<String> uris(PlaybackSession s) => [
      for (final i in s.order) s.tracks[i].uri,
    ];

    for (final uri in bad) {
      test(
        '${uri.replaceAll('\u0000', '<NUL>')} is dropped, not the session',
        () {
          final back = decodePlaybackSession(
            sessionOf(['/music/a.flac', uri, '/music/b.mp3']),
          );

          expect(uris(back), ['/music/a.flac', '/music/b.mp3']);
          expect(back.tracks.map((t) => t.uri), [
            '/music/a.flac',
            '/music/b.mp3',
          ]);
          expect(back.order, [0, 1]);
        },
      );
    }

    test('plain absolute audio paths are all kept', () {
      const good = [
        '/music/a.flac',
        '/music/B.MP3',
        '/music/dir with space/c.opus',
        '/music/d.m4a',
      ];
      final back = decodePlaybackSession(sessionOf(good));

      expect(uris(back), good);
    });

    test('the current track stays current, position kept', () {
      final back = decodePlaybackSession(
        sessionOf([
          'http://x/a.mp3',
          '/music/b.flac',
          'edl://c',
          '/music/d.flac',
        ], index: 3),
      );

      expect(uris(back), ['/music/b.flac', '/music/d.flac']);
      expect(back.index, 1);
      expect(back.position, const Duration(seconds: 5));
    });

    test('a dropped current track passes to the one that took its place', () {
      final back = decodePlaybackSession(
        sessionOf([
          '/music/a.flac',
          'http://x/b.mp3',
          '/music/c.flac',
          '/music/d.flac',
        ], index: 1),
      );

      expect(uris(back), ['/music/a.flac', '/music/c.flac', '/music/d.flac']);
      expect(back.index, 1);
      expect(back.tracks[back.order[back.index]].uri, '/music/c.flac');
      expect(back.position, Duration.zero);
    });

    test('a dropped current track at the end passes to the last one left', () {
      final back = decodePlaybackSession(
        sessionOf([
          '/music/a.flac',
          '/music/b.flac',
          'http://x/c.mp3',
        ], index: 2),
      );

      expect(uris(back), ['/music/a.flac', '/music/b.flac']);
      expect(back.index, 1);
      expect(back.position, Duration.zero);
    });

    test('renumbers a shuffled order and the unshuffled one', () {
      // Tracks 0 and 2 are fine; 1 and 3 are not. Plays 3, 2, 0, 1; current
      // is 0, which survives.
      final back = decodePlaybackSession(
        sessionOf(
          ['/music/a.flac', 'http://x', '/music/c.flac', 'edl://d'],
          order: [3, 2, 0, 1],
          unshuffled: [0, 1, 2, 3],
          index: 2,
        ),
      );

      expect(back.tracks.map((t) => t.uri), ['/music/a.flac', '/music/c.flac']);
      expect(back.order, [1, 0]);
      expect(back.unshuffledOrder, [0, 1]);
      expect(back.index, 1);
      expect(back.position, const Duration(seconds: 5));
    });

    test('a track that is not in the order is dropped too', () {
      final back = decodePlaybackSession(
        sessionOf(
          ['http://x', '/music/b.flac', '/music/c.flac'],
          order: [2, 1],
          index: 1,
        ),
      );

      expect(back.tracks.map((t) => t.uri), ['/music/b.flac', '/music/c.flac']);
      expect(back.order, [1, 0]);
      expect(back.index, 1);
    });

    test('nothing left gives an empty queue at index 0', () {
      final back = decodePlaybackSession(
        sessionOf(['http://x', 'edl://y'], index: 1),
      );

      expect(back.tracks, isEmpty);
      expect(back.order, isEmpty);
      expect(back.index, 0);
    });

    test('a bad session is still rejected as a whole', () {
      final json = sessionOf(['/music/a.flac', 'http://x'], index: 5);

      expect(() => decodePlaybackSession(json), throwsFormatException);
    });

    test('the warning names a count, never a path', () {
      final records = <LogRecord>[];
      final previous = Logger.root.level;
      Logger.root.level = Level.ALL;
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(() {
        subscription.cancel();
        Logger.root.level = previous;
      });

      decodePlaybackSession(
        sessionOf([
          '/music/a.flac',
          'http://secret.test/x.mp3',
          '/music/b.txt',
        ]),
      );

      final text = records.map((r) => r.message).join('\n');
      expect(records, hasLength(1));
      expect(text, contains('2'));
      expect(text, isNot(contains('secret')));
      expect(text, isNot(contains('b.txt')));
    });
  });

  group('cover keys', () {
    const dir = '/cache/covers/512';
    final key = 'ab/${'ab'.padRight(64, '0')}.jpg';
    final thumb = Track(uri: '/music/t.flac', title: 'T', artUri: '$dir/$key');

    PlaybackSession oneTrack(Track track) =>
        PlaybackSession(tracks: [track], order: const [0]);

    Map<String, Object?> encode(Track track, {String? coverDirectory = dir}) =>
        jsonDecode(
          jsonEncode(
            encodePlaybackSession(
              oneTrack(track),
              coverDirectory: coverDirectory,
            ),
          ),
        ) as Map<String, Object?>;

    Map<String, Object?> firstTrack(Map<String, Object?> json) =>
        ((json['tracks']! as List).first as Map).cast<String, Object?>();

    test('a thumbnail inside the folder is stored as its key only', () {
      final saved = firstTrack(encode(thumb));

      expect(saved['coverKey'], key);
      expect(saved.containsKey('artUri'), isFalse);
    });

    test('external art keeps its artUri', () {
      final saved = firstTrack(encode(a));

      expect(saved['artUri'], '/covers/a.jpg');
      expect(saved.containsKey('coverKey'), isFalse);
    });

    test('no art stores no key', () {
      final saved = firstTrack(encode(b));

      expect(saved.containsKey('coverKey'), isFalse);
      expect(saved['artUri'], isNull);
    });

    test('without a folder the path is stored as it is', () {
      final saved = firstTrack(encode(thumb, coverDirectory: null));

      expect(saved['artUri'], '$dir/$key');
      expect(saved.containsKey('coverKey'), isFalse);
    });

    test('the same folder gives the same art back', () {
      final back = decodePlaybackSession(encode(thumb), coverDirectory: dir);

      expect(back.tracks.single.artUri, '$dir/$key');
    });

    test('another folder moves the art with it', () {
      final back = decodePlaybackSession(
        encode(thumb),
        coverDirectory: '/other/covers/512',
      );

      expect(back.tracks.single.artUri, '/other/covers/512/$key');
    });

    test('a key with no folder has no art', () {
      expect(decodePlaybackSession(encode(thumb)).tracks.single.artUri, isNull);
    });

    test('a malformed key has no art', () {
      final json = encode(thumb);
      firstTrack(json)['coverKey'] = '../x';

      expect(
        decodePlaybackSession(json, coverDirectory: dir).tracks.single.artUri,
        isNull,
      );
    });

    test('a key that is not a string is rejected', () {
      final json = encode(thumb);
      firstTrack(json)['coverKey'] = 5;

      expect(
        () => decodePlaybackSession(json, coverDirectory: dir),
        throwsFormatException,
      );
    });

    test('a file without keys still loads, its artUri kept', () {
      final back = decodePlaybackSession(valid(), coverDirectory: dir);

      expect(back.tracks.first.artUri, '/covers/a.jpg');
    });

    test('the version stays the same', () {
      expect(encode(thumb)['version'], playbackSessionVersion);
      expect(playbackSessionVersion, 1);
    });
  });
}
