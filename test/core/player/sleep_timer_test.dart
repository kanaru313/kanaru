import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/album_run_lookup.dart';
import 'package:kanaru/core/player/playback_fade.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/replay_gain_options.dart';
import 'package:kanaru/core/player/sleep_timer.dart';
import 'package:kanaru/core/player/track.dart';

import 'fake_audio_backend.dart';
import 'manual_fade_clock.dart';

final _songs = [
  for (final name in ['a', 'b', 'c', 'd']) Track.fromPath('/music/$name.mp3'),
];

const AlbumRunKey _x = (artist: 'x', title: 'x');
const AlbumRunKey _y = (artist: 'y', title: 'y');

/// a and b share an album, c has none, d has another one.
final _albums = {'/music/a.mp3': _x, '/music/b.mp3': _x, '/music/d.mp3': _y};

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;
  late ManualFadeClock time;
  late List<double> volumes;
  late AlbumRunKeyLookup lookup;

  PlayerService player() => container.read(playerServiceProvider.notifier);
  SleepTimer timer() => container.read(sleepTimerProvider.notifier);
  SleepTimerState timerState() => container.read(sleepTimerProvider);
  bool stopFlag() => player().stopAfterCurrent;

  setUp(() {
    backend = FakeAudioBackend();
    time = ManualFadeClock();
    volumes = [];
    lookup = (paths) async => {for (final path in paths) path: ?_albums[path]};
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        playbackFadeClockProvider.overrideWithValue(time.clock),
        sleepTimerAlbumLookupProvider.overrideWith(
          (ref) =>
              (p) => lookup(p),
        ),
      ],
    );
    container.listen(
      playerServiceProvider,
      (_, next) => volumes.add(next.volume),
    );
    container.listen(sleepTimerProvider, (_, _) {});
  });
  tearDown(() {
    container.dispose();
    expect(volumes.toSet(), anyOf(isEmpty, {100.0}), reason: 'never faded');
  });

  Future<void> open({int start = 0}) async {
    await player().openTracks(_songs, start: start);
    await pumpMicrotasks();
    backend.calls.clear();
  }

  group('minutes', () {
    test('counts down and clamps to 1..720 minutes', () async {
      timer().startMinutes(0);
      expect(timerState().remaining, const Duration(minutes: 1));
      timer().startMinutes(1000);
      expect(timerState().remaining, const Duration(minutes: 720));

      timer().startMinutes(2);
      await time.advance(const Duration(seconds: 30));
      expect(timerState().mode, SleepTimerMode.minutes);
      expect(timerState().remaining, const Duration(seconds: 90));
    });

    test('adds and takes off 5 minutes, never down to zero', () async {
      timer().startMinutes(10);
      timer().addMinutes(5);
      expect(timerState().remaining, const Duration(minutes: 15));
      timer().addMinutes(-5);
      expect(timerState().remaining, const Duration(minutes: 10));

      timer().startMinutes(5);
      expect(timerState().canSubtract(5), isFalse);
      timer().addMinutes(-5);
      expect(timerState().remaining, const Duration(minutes: 5));

      timer().startMinutes(718);
      timer().addMinutes(5);
      expect(timerState().remaining, const Duration(minutes: 720));
    });

    test('pausing the count holds it; resuming goes on', () async {
      await open();
      timer().startMinutes(1);
      await time.advance(const Duration(seconds: 30));
      timer().pauseCounting();
      expect(timerState().countingPaused, isTrue);

      await time.advance(const Duration(minutes: 2));
      expect(timerState().remaining, const Duration(seconds: 30));
      timer().addMinutes(1);
      expect(timerState().remaining, const Duration(seconds: 90));

      timer().resumeCounting();
      await time.advance(const Duration(seconds: 89));
      expect(timerState().active, isTrue);
      await time.advance(const Duration(seconds: 1));
      expect(timerState().active, isFalse);
      expect(container.read(playerServiceProvider).playing, isFalse);
    });

    test('fades out over the last 10 s, then pauses at full volume', () async {
      await open();
      timer().startMinutes(1);

      await time.advance(const Duration(seconds: 50));
      expect(backend.calls, isEmpty);
      await time.advance(const Duration(seconds: 5));
      expect(container.read(playerServiceProvider).playing, isTrue);
      final faded = backend.calls.last;
      expect(faded, startsWith('setVolume('));
      expect(faded, isNot('setVolume(100.0)'));

      await time.advance(const Duration(seconds: 5));
      expect(timerState().active, isFalse);
      expect(container.read(playerServiceProvider).playing, isFalse);
      expect(backend.calls.where((c) => c == 'pause'), hasLength(1));
      expect(backend.calls.last, 'setVolume(100.0)');
      expect(time.activeTimers, 0);
    });

    test('keeps fading when the engine moves on to the next track', () async {
      await open();
      timer().startMinutes(1);
      await time.advance(const Duration(seconds: 55));
      backend.calls.clear();

      backend.advance();
      await time.advance(const Duration(seconds: 1));

      final volumesSent = backend.calls.where((c) => c.startsWith('setV'));
      expect(volumesSent, isNotEmpty);
      expect(volumesSent, isNot(contains('setVolume(100.0)')));
    });

    test('pausing the count or adding time ends the fade', () async {
      await open();
      timer().startMinutes(1);
      await time.advance(const Duration(seconds: 55));

      timer().pauseCounting();
      expect(backend.calls.last, 'setVolume(100.0)');
      timer().resumeCounting();
      await time.advance(const Duration(seconds: 1));
      expect(backend.calls.last, isNot('setVolume(100.0)'));

      timer().addMinutes(5);
      expect(backend.calls.last, 'setVolume(100.0)');
      expect(player().sleepFading, isFalse);
    });

    test('keeps counting while paused; expiring then only turns off', () async {
      await open();
      await player().pause();
      backend.calls.clear();
      timer().startMinutes(1);

      await time.advance(const Duration(seconds: 30));
      expect(timerState().remaining, const Duration(seconds: 30));
      await time.advance(const Duration(seconds: 30));

      expect(timerState().active, isFalse);
      expect(backend.calls, isEmpty);
    });

    test('a fade the user interrupted is not started again', () async {
      await open();
      timer().startMinutes(1);
      await time.advance(const Duration(seconds: 55));
      expect(player().sleepFading, isTrue);

      await player().pause();
      await player().play();
      await time.advance(const Duration(seconds: 4));
      expect(player().sleepFading, isFalse);
      expect(container.read(playerServiceProvider).playing, isTrue);
      backend.calls.clear();

      await time.advance(const Duration(seconds: 1));
      expect(timerState().active, isFalse);
      expect(container.read(playerServiceProvider).playing, isFalse);
      expect(backend.calls.first, 'pause', reason: 'no fade before it');
    });

    test('added time arms the fade again after an interruption', () async {
      await open();
      timer().startMinutes(1);
      await time.advance(const Duration(seconds: 55));
      await player().pause();
      await player().play();
      await time.advance(const Duration(seconds: 1));

      timer().addMinutes(5);
      await time.advance(const Duration(minutes: 5));
      expect(player().sleepFading, isTrue);
    });

    test('cancel turns it off and undoes the fade', () async {
      await open();
      timer().startMinutes(1);
      await time.advance(const Duration(seconds: 55));

      timer().cancel();
      expect(timerState(), const SleepTimerState.off());
      expect(backend.calls.last, 'setVolume(100.0)');
      await time.advance(const Duration(seconds: 10));
      expect(container.read(playerServiceProvider).playing, isTrue);
    });
  });

  group('end of track', () {
    test('stops after the current track, then turns off', () async {
      await open();
      timer().startEndOfTrack();
      expect(stopFlag(), isTrue);

      backend.emitCompleted.add(true);
      await pumpMicrotasks();

      expect(timerState().active, isFalse);
      expect(stopFlag(), isFalse);
      expect(container.read(playerServiceProvider).queue.index, 1);
      expect(container.read(playerServiceProvider).playing, isFalse);
    });

    test('cancel clears the stop', () async {
      await open();
      timer().startEndOfTrack();
      timer().cancel();
      expect(stopFlag(), isFalse);
    });

    test('disposing the timer clears the stop', () async {
      await open();
      timer().startEndOfTrack();
      container.invalidate(sleepTimerProvider);
      timerState();
      await pumpMicrotasks();
      expect(stopFlag(), isFalse);
    });

    test('a rebuilt timer still hears the stop', () async {
      await open();
      container.invalidate(sleepTimerProvider);
      timerState();
      timer().startEndOfTrack();
      await pumpMicrotasks();
      expect(stopFlag(), isTrue, reason: 'the old build did not clear it');

      backend.emitCompleted.add(true);

      expect(timerState().active, isFalse);
      expect(stopFlag(), isFalse);
    });

    test('a rebuilt player gets the stop again and still reports it', () async {
      await open();
      timer().startEndOfTrack();

      container.invalidate(playerServiceProvider);
      container.read(playerServiceProvider);
      await pumpMicrotasks();
      expect(stopFlag(), isTrue);

      backend.emitCompleted.add(true);
      expect(timerState().active, isFalse);
    });
  });

  group('end of queue', () {
    test('stops only on the last track in play order', () async {
      await open();
      timer().startEndOfQueue();
      expect(stopFlag(), isFalse);

      await player().jump(3);
      expect(stopFlag(), isTrue);
      await player().jump(1);
      expect(stopFlag(), isFalse);
      backend.advance();
      backend.advance();
      expect(stopFlag(), isTrue);

      backend.emitCompleted.add(true);
      expect(timerState().active, isFalse);
    });
  });

  group('end of album', () {
    Future<bool> flagAt(int index) async {
      await player().jump(index);
      await pumpMicrotasks();
      return stopFlag();
    }

    test('stops where the next track has another album or none', () async {
      await open();
      timer().startEndOfAlbum();
      await pumpMicrotasks();

      expect(stopFlag(), isFalse, reason: 'a then b, same album');
      expect(await flagAt(1), isTrue, reason: 'c has no album');
      expect(await flagAt(2), isTrue, reason: 'c is an album of its own');
      expect(await flagAt(3), isTrue, reason: 'nothing follows d');
      expect(await flagAt(0), isFalse);
    });

    test('the last track of a shuffled pass ends its album', () async {
      lookup = (paths) async => {for (final path in paths) path: _x};
      await open();
      await player().setRepeat(RepeatMode.all);
      timer().startEndOfAlbum();
      await pumpMicrotasks();
      expect(await flagAt(3), isFalse, reason: 'repeat all wraps to a, same');

      await player().setRepeat(RepeatMode.allShuffled);
      await pumpMicrotasks();

      expect(stopFlag(), isTrue, reason: 'a new random order follows');
      expect(await flagAt(0), isFalse);
    });

    test('moving on inside an album never withdraws the next track', () async {
      lookup = (paths) async => {for (final path in paths) path: _x};
      await open();
      timer().startEndOfAlbum();
      await pumpMicrotasks();
      backend.calls.clear();

      backend.advance();
      await pumpMicrotasks();
      backend.advance();
      await pumpMicrotasks();

      expect(backend.calls, ['setNext(c)', 'setNext(d)']);
      expect(stopFlag(), isFalse, reason: 'c then d, same album');
    });

    test('assumes a stop while the keys are read', () async {
      final gate = Completer<void>();
      final real = lookup;
      lookup = (paths) async {
        await gate.future;
        return real(paths);
      };
      await open();
      timer().startEndOfAlbum();
      expect(stopFlag(), isTrue);

      gate.complete();
      await pumpMicrotasks();
      expect(stopFlag(), isFalse, reason: 'a then b, same album');
    });

    test('drops a decision for a track that is no longer current', () async {
      final gate = Completer<void>();
      lookup = (paths) async {
        await gate.future;
        return {for (final path in paths) path: ?_albums[path]};
      };
      await open(start: 1);
      timer().startEndOfAlbum();
      await player().jump(0);

      gate.complete();
      await pumpMicrotasks();
      expect(stopFlag(), isFalse, reason: 'a then b, not b then c');
    });
  });

  test('a new mode replaces the old one', () async {
    await open();
    timer().startMinutes(1);
    timer().startEndOfTrack();
    expect(stopFlag(), isTrue);

    await time.advance(const Duration(minutes: 2));
    expect(timerState().mode, SleepTimerMode.endOfTrack);
    expect(container.read(playerServiceProvider).playing, isTrue);

    timer().startMinutes(5);
    expect(stopFlag(), isFalse);
  });
}
