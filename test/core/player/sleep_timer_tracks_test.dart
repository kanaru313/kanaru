import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/playback_fade.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/sleep_timer.dart';
import 'package:kanaru/core/player/track.dart';

import 'fake_audio_backend.dart';
import 'manual_fade_clock.dart';

final _songs = [
  for (final name in ['a', 'b', 'c', 'd', 'e'])
    Track.fromPath('/music/$name.mp3'),
];

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;
  late ManualFadeClock time;

  PlayerService player() => container.read(playerServiceProvider.notifier);
  SleepTimer timer() => container.read(sleepTimerProvider.notifier);
  SleepTimerState timerState() => container.read(sleepTimerProvider);
  bool stopFlag() => player().stopAfterCurrent;

  setUp(() {
    backend = FakeAudioBackend();
    time = ManualFadeClock();
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        playbackFadeClockProvider.overrideWithValue(time.clock),
      ],
    );
    container.listen(playerServiceProvider, (_, _) {});
    container.listen(sleepTimerProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  Future<void> open({int start = 0}) async {
    await player().openTracks(_songs, start: start);
    await pumpMicrotasks();
    backend.calls.clear();
  }

  test('counts finished tracks and pauses after the last one', () async {
    await open();
    timer().startTracks(3);
    expect(timerState().tracksLeft, 3);
    expect(stopFlag(), isFalse);

    backend.advance();
    expect(timerState().tracksLeft, 2);
    expect(stopFlag(), isFalse);
    backend.advance();
    expect(timerState().tracksLeft, 1);
    expect(stopFlag(), isTrue);

    backend.emitCompleted.add(true);
    expect(timerState().active, isFalse);
    expect(stopFlag(), isFalse);
    expect(player().state.playing, isFalse);
    expect(player().state.queue.current?.title, 'd');
  });

  test('one track is the end of track behaviour', () async {
    await open();
    timer().startTracks(1);
    expect(stopFlag(), isTrue);
    backend.emitCompleted.add(true);
    expect(timerState().active, isFalse);
  });

  test('skip, previous and jump use no track up', () async {
    await open(start: 1);
    timer().startTracks(3);
    await player().next();
    await player().previous();
    await player().jump(3);
    expect(timerState().tracksLeft, 3);

    timer().addTracks(-2);
    expect(stopFlag(), isTrue);
    await player().next();
    expect(timerState().tracksLeft, 1);
    expect(stopFlag(), isTrue);
  });

  test('seeking does not count', () async {
    await open();
    timer().startTracks(2);
    await player().seek(const Duration(seconds: 30));
    await player().seek(Duration.zero);
    expect(timerState().tracksLeft, 2);
  });

  test('repeat one counts each loop and rests after the last', () async {
    await open();
    await player().setRepeat(RepeatMode.one);
    timer().startTracks(3);
    final a = _songs.first;
    backend.emitLooped.add(a);
    expect(timerState().tracksLeft, 2);
    backend.emitLooped.add(a);
    expect(timerState().tracksLeft, 1);
    expect(stopFlag(), isTrue);
    backend.emitLooped.add(a);
    expect(timerState().active, isFalse);
    expect(player().state.playing, isFalse);
    expect(player().state.position, Duration.zero);
  });

  test('a counted repeat counts its loops', () async {
    await open();
    await player().setRepeatTimes(2);
    timer().startTracks(5);
    backend.emitLooped.add(_songs.first);
    expect(timerState().tracksLeft, 4);
    backend.emitLooped.add(_songs.first);
    expect(timerState().tracksLeft, 3);
  });

  test('turns off when the queue runs out first', () async {
    await open(start: 4);
    timer().startTracks(3);
    backend.emitCompleted.add(true);
    expect(player().state.stopped, isTrue);
    expect(timerState().active, isFalse);
    expect(stopFlag(), isFalse);
  });

  test('a failed track does not count', () async {
    await open();
    timer().startTracks(3);
    backend.fail(_songs[1]);
    backend.advance();
    expect(timerState().tracksLeft, 3);

    backend.emitDuration.add(const Duration(seconds: 100));
    backend.advance();
    expect(timerState().tracksLeft, 2);
  });

  test('adding and removing tracks moves the stop', () async {
    await open();
    timer().startTracks(1);
    expect(stopFlag(), isTrue);
    timer().addTracks(1);
    await pumpMicrotasks();
    expect(timerState().tracksLeft, 2);
    expect(stopFlag(), isFalse);
    expect(backend.calls, contains('setNext(b)'));

    timer().addTracks(-1);
    expect(timerState().tracksLeft, 1);
    expect(stopFlag(), isTrue);
    timer().addTracks(-1);
    expect(timerState().tracksLeft, 1);
    expect(timerState().canRemoveTrack, isFalse);

    timer().startTracks(20);
    expect(timerState().canAddTrack, isFalse);
    timer().addTracks(1);
    expect(timerState().tracksLeft, 20);

    timer().startTracks(0);
    expect(timerState().tracksLeft, 1);
    timer().startTracks(99);
    expect(timerState().tracksLeft, 20);
  });

  test('a rebuilt player gets the stop again and still counts', () async {
    await open();
    timer().startTracks(3);
    container.invalidate(playerServiceProvider);
    container.read(playerServiceProvider);
    await pumpMicrotasks();
    expect(stopFlag(), isFalse);

    backend.advance();
    expect(timerState().tracksLeft, 2);
  });

  test('another mode replaces it and cancel clears the stop', () async {
    await open();
    timer().startTracks(1);
    timer().startMinutes(5);
    expect(timerState().mode, SleepTimerMode.minutes);
    expect(timerState().tracksLeft, 0);
    expect(stopFlag(), isFalse);

    timer().startTracks(1);
    expect(stopFlag(), isTrue);
    timer().cancel();
    expect(timerState().active, isFalse);
    expect(stopFlag(), isFalse);
    timer().addTracks(1);
    expect(timerState().active, isFalse);
  });
}
