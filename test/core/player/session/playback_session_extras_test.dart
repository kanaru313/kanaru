import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/play_queue.dart';
import 'package:kanaru/core/player/player_state.dart';
import 'package:kanaru/core/player/session/playback_session.dart';
import 'package:kanaru/core/player/session/playback_session_codec.dart';
import 'package:kanaru/core/player/session/playback_session_file.dart';
import 'package:kanaru/core/player/session/playback_session_saver.dart';
import 'package:kanaru/core/player/track.dart';

class _RecordingFile extends PlaybackSessionFile {
  _RecordingFile() : super('/nonexistent/playback-session.json');

  final saves = <PlaybackSession>[];

  @override
  Future<bool> save(PlaybackSession session) async {
    saves.add(session);
    return true;
  }
}

class _ManualTimer implements Timer {
  _ManualTimer(this.delay, this._callback);

  final Duration delay;
  final void Function() _callback;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

const _a = Track(uri: '/music/a.flac', title: 'A');
const _b = Track(uri: '/music/b.flac', title: 'B');

void main() {
  group('codec', () {
    const extras = {
      'k': {'service': 'x', 'n': 3},
    };

    Map<String, Object?> encoded(PlaybackSession session) =>
        jsonDecode(jsonEncode(encodePlaybackSession(session)))
            as Map<String, Object?>;

    PlaybackSession withExtras(Map<String, Object?> e) =>
        PlaybackSession(tracks: const [_a, _b], order: const [0, 1], extras: e);

    test('round trips extras', () {
      final back = decodePlaybackSession(encoded(withExtras(extras)));
      expect(back.extras, extras);
      expect(() => back.extras['z'] = 1, throwsUnsupportedError);
    });

    test('empty extras are left out, and a missing key reads as empty', () {
      final json = encoded(withExtras(const {}));
      expect(json.containsKey('extras'), isFalse);
      expect(decodePlaybackSession(json).extras, isEmpty);
    });

    test('a value that is not an object reads as empty', () {
      final json = encoded(withExtras(extras))..['extras'] = [1, 2];
      expect(decodePlaybackSession(json).extras, isEmpty);
    });

    test('the version stays the same, and an old file reads', () {
      expect(encoded(withExtras(extras))['version'], playbackSessionVersion);
      expect(playbackSessionVersion, 1);
      final old = encoded(withExtras(const {}));
      expect(decodePlaybackSession(old).tracks, hasLength(2));
    });

    test('dropping a track that cannot be restored keeps extras', () {
      final session = PlaybackSession(
        tracks: const [
          _a,
          Track(uri: 'http://x/y.mp3', title: 'remote'),
        ],
        order: const [0, 1],
        extras: extras,
      );
      final back = decodePlaybackSession(encoded(session));
      expect(back.tracks, hasLength(1));
      expect(back.extras, extras);
    });

    test('withPosition keeps extras', () {
      expect(withExtras(extras).withPosition(Duration.zero).extras, extras);
    });

    test('extras compare by identity', () {
      final one = <String, Object?>{'k': 1};
      expect(withExtras(one), withExtras(one));
      expect(withExtras(one), isNot(withExtras({'k': 1})));
    });
  });

  group('saver', () {
    late _RecordingFile file;
    late List<_ManualTimer> timers;
    late PlaybackSessionSaver saver;
    late PlayerState state;
    var extras = const <String, Object?>{};

    PlaybackSessionSaver make({bool frozen = false}) => PlaybackSessionSaver(
      file,
      frozen: frozen,
      extras: () => extras,
      timer: (delay, callback) {
        final timer = _ManualTimer(delay, callback);
        timers.add(timer);
        return timer;
      },
    );

    void fireCoalesce() {
      for (final timer in [...timers]) {
        if (timer.delay == PlaybackSessionSaver.coalesceDelay) timer.fire();
      }
    }

    setUp(() {
      file = _RecordingFile();
      timers = [];
      extras = const {};
      saver = make();
      state = PlayerState(queue: PlayQueue(original: const [_a, _b], index: 0));
      saver.onState(null, state);
      // Already written once: only the extras differ now.
      saver.onExtrasChanged();
      fireCoalesce();
      file.saves.clear();
    });

    test('an extras-only change while paused writes after the delay', () {
      extras = {'k': 1};
      saver.onExtrasChanged();
      expect(file.saves, isEmpty);
      fireCoalesce();
      expect(file.saves.single.extras, {'k': 1});
    });

    test('flush writes extras', () async {
      extras = {'k': 2};
      await saver.flush();
      expect(file.saves.last.extras, {'k': 2});
    });

    test('a frozen saver writes nothing', () {
      saver = make(frozen: true);
      saver.onState(null, state);
      extras = {'k': 3};
      saver.onExtrasChanged();
      fireCoalesce();
      expect(file.saves, isEmpty);
    });

    test('an equal map object is not written twice', () {
      extras = {'k': 4};
      saver.onExtrasChanged();
      fireCoalesce();
      saver.onExtrasChanged();
      fireCoalesce();
      expect(file.saves, hasLength(1));
    });
  });
}
