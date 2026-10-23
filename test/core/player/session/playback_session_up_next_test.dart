import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/session/playback_session.dart';
import 'package:kanaru/core/player/session/playback_session_codec.dart';
import 'package:kanaru/core/player/session/playback_session_file.dart';
import 'package:kanaru/core/player/track.dart';

const a = Track(uri: '/music/a.flac', title: 'A');
const b = Track(uri: '/music/b.flac', title: 'B');
const c = Track(uri: '/music/c.flac', title: 'C');
const d = Track(uri: '/music/d.flac', title: 'D');

PlaybackSession _decode(Map<String, Object?> json) =>
    decodePlaybackSession(jsonDecode(jsonEncode(json)) as Map<String, Object?>);

void main() {
  group('codec', () {
    const session = PlaybackSession(
      tracks: [a, b, c, d],
      order: [0, 3, 1, 2],
      upNext: [3, 1],
    );

    test('play next entries round-trip', () {
      final back = _decode(encodePlaybackSession(session));
      expect(back, session);
      expect(back.upNext, [3, 1]);
    });

    test('an empty list is not written, so the file keeps its old shape', () {
      final json = encodePlaybackSession(session.withPosition(Duration.zero));
      expect(json['upNext'], [3, 1]);
      const plain = PlaybackSession(tracks: [a], order: [0]);
      expect(encodePlaybackSession(plain).containsKey('upNext'), isFalse);
    });

    test('a file of an older build, without the key, restores none', () {
      final json = encodePlaybackSession(session)..remove('upNext');
      expect(_decode(json).upNext, isEmpty);
    });

    test('broken entries are dropped, the session still restores', () {
      for (final raw in <Object?>[
        'x',
        42,
        {'a': 1},
        [-1, 4, 99, 'x', 1.5, null, 2, 2],
      ]) {
        final json = encodePlaybackSession(session)..['upNext'] = raw;
        final back = _decode(json);
        expect(back.order, session.order, reason: '$raw');
        expect(back.upNext, raw is List ? [2] : isEmpty, reason: '$raw');
      }
    });

    test('dropping a track that cannot be restored renumbers them', () {
      const bad = Track(uri: 'http://example.test/x.mp3', title: 'X');
      const withBad = PlaybackSession(
        tracks: [a, bad, b, c],
        order: [0, 2, 1, 3],
        upNext: [2, 1, 3],
      );
      final back = _decode(encodePlaybackSession(withBad));
      expect(back.tracks, [a, b, c]);
      expect(back.upNext, [1, 2]);
    });

    test('the composed text reads back the same as the plain encoding', () {
      const shuffled = PlaybackSession(
        tracks: [a, b, c],
        order: [2, 0, 1],
        unshuffledOrder: [0, 1, 2],
        shuffled: true,
        index: 1,
        upNext: [1],
        volumeBeforeMute: 30,
        volume: 0,
      );
      final text = composePlaybackSessionJson(
        light: encodePlaybackSessionLight(shuffled),
        tracksJson: jsonEncode(
          encodePlaybackSessionTracks(shuffled.tracks, null),
        ),
        orderJson: jsonEncode(shuffled.order),
        unshuffledJson: jsonEncode(shuffled.unshuffledOrder),
      );
      expect(
        jsonDecode(text),
        jsonDecode(jsonEncode(encodePlaybackSession(shuffled))),
      );
    });
  });

  group('restoredUpNext', () {
    test('keeps only entries still to come', () {
      const session = PlaybackSession(
        tracks: [a, b, c, d],
        order: [0, 1, 2, 3],
        index: 1,
        upNext: [0, 1, 2, 3],
      );
      expect(session.restoredUpNext(), {2, 3});
    });

    test('follows the renumbering of removed tracks', () {
      // b (entry 1) was removed from the queue: the order skips it.
      const session = PlaybackSession(
        tracks: [a, b, c, d],
        order: [0, 2, 3],
        upNext: [1, 3],
      );
      final queue = session.toQueue();
      expect(queue.original, [a, c, d]);
      expect(session.restoredUpNext(), {2});
      expect(queue.original[2], d);
    });

    test('an empty queue has none', () {
      const session = PlaybackSession(upNext: [0]);
      expect(session.restoredUpNext(), isEmpty);
    });
  });

  group('file', () {
    late Directory root;
    late String path;

    setUp(() {
      root = Directory.systemTemp.createTempSync('kanaru_session_up_next_');
      path = '${root.path}/playback-session.json';
    });
    tearDown(() => root.deleteSync(recursive: true));

    test('a new track list with the same length is written anew', () async {
      final file = PlaybackSessionFile(path);
      const first = PlaybackSession(tracks: [a, b], order: [0, 1]);
      await file.save(first);
      // Same length and order list, new list objects with other titles.
      final renamed = PlaybackSession(
        tracks: const [
          Track(uri: '/music/a.flac', title: 'A2'),
          Track(uri: '/music/b.flac', title: 'B2'),
        ],
        order: first.order,
      );
      await file.save(renamed);

      final back = PlaybackSessionFile(path).load()!;
      expect(back.tracks.map((t) => t.title), ['A2', 'B2']);
    });

    test('a position-only save keeps the tracks and order on disk', () async {
      final file = PlaybackSessionFile(path);
      const first = PlaybackSession(
        tracks: [a, b, c],
        order: [2, 0, 1],
        unshuffledOrder: [0, 1, 2],
        shuffled: true,
        upNext: [1],
      );
      await file.save(first);
      for (var s = 1; s <= 3; s++) {
        await file.save(first.withPosition(Duration(seconds: s)));
      }

      final back = PlaybackSessionFile(path).load()!;
      expect(back, first.withPosition(const Duration(seconds: 3)));
    });

    test('quick saves of changing queues end with the newest', () async {
      final file = PlaybackSessionFile(path);
      final sessions = [
        for (var n = 1; n <= 4; n++)
          PlaybackSession(
            tracks: [
              for (var i = 0; i < n; i++) Track(uri: '/m/$i.flac', title: '$i'),
            ],
            order: [for (var i = 0; i < n; i++) i],
          ),
      ];
      final saves = [for (final s in sessions) file.save(s)];
      await Future.wait(saves);
      await file.flush();

      expect(PlaybackSessionFile(path).load(), sessions.last);
    });

    test('a failed write is reported and the next one encodes again', () async {
      // A directory where the file goes makes the rename fail.
      Directory(path).createSync();
      final file = PlaybackSessionFile(path);
      const session = PlaybackSession(tracks: [a], order: [0]);
      expect(await file.save(session), isFalse);
      final leftovers = root.listSync().where((e) => e.path.endsWith('.tmp'));
      expect(leftovers, isEmpty);

      Directory(path).deleteSync();
      expect(await file.save(session.withPosition(Duration.zero)), isTrue);
      expect(PlaybackSessionFile(path).load(), session);
    });
  });
}
