import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/play_queue.dart';
import 'package:kanaru/core/player/player_state.dart';
import 'package:kanaru/core/player/session/playback_session.dart';
import 'package:kanaru/core/player/session/playback_session_file.dart';
import 'package:kanaru/core/player/session/playback_session_saver.dart';
import 'package:kanaru/core/player/track.dart';

/// Records snapshots instead of writing them.
class _RecordingFile extends PlaybackSessionFile {
  _RecordingFile() : super('/nonexistent/playback-session.json');

  final saves = <PlaybackSession>[];

  /// Whether the next writes report success, like a full disk would not.
  bool succeeds = true;

  @override
  Future<bool> save(PlaybackSession session) async {
    saves.add(session);
    return succeeds;
  }
}

/// Timer that only fires when the test says so.
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
const _c = Track(uri: '/music/c.flac', title: 'C');

void main() {
  late _RecordingFile file;
  late List<_ManualTimer> timers;
  late PlaybackSessionSaver saver;
  late PlayerState state;

  PlaybackSessionSaver makeSaver({
    PlaybackSession? initial,
    bool frozen = false,
  }) => PlaybackSessionSaver(
    file,
    initial: initial,
    frozen: frozen,
    timer: (delay, callback) {
      final timer = _ManualTimer(delay, callback);
      timers.add(timer);
      return timer;
    },
  );

  /// Applies [next] the way `listenSelf` reports it.
  void emit(PlayerState next) {
    final previous = state;
    state = next;
    saver.onState(previous, next);
  }

  void fireAll(Duration delay) {
    for (final timer in [...timers]) {
      if (timer.delay == delay) timer.fire();
    }
  }

  final queue = PlayQueue(original: const [_a, _b, _c], index: 1);

  setUp(() {
    file = _RecordingFile();
    timers = [];
    saver = makeSaver();
    state = PlayerState(queue: queue);
    saver.onState(null, state);
  });

  test('ten volume changes are one write', () {
    for (var v = 10; v <= 100; v += 10) {
      emit(state.copyWith(volume: v.toDouble()));
    }
    expect(file.saves, isEmpty);

    fireAll(PlaybackSessionSaver.coalesceDelay);

    expect(file.saves, hasLength(1));
    expect(file.saves.single.volume, 100);
  });

  test('saves the position every interval while playing only', () {
    emit(state.copyWith(playing: true));
    emit(state.copyWith(position: const Duration(seconds: 4)));
    fireAll(PlaybackSessionSaver.positionInterval);
    expect(file.saves.last.position, const Duration(seconds: 4));

    emit(state.copyWith(position: const Duration(seconds: 14)));
    fireAll(PlaybackSessionSaver.positionInterval);
    expect(file.saves.last.position, const Duration(seconds: 14));
    final count = file.saves.length;

    // Pausing saves at once and stops the periodic write.
    emit(state.copyWith(position: const Duration(seconds: 16)));
    emit(state.copyWith(playing: false));
    expect(file.saves.last.position, const Duration(seconds: 16));
    expect(file.saves, hasLength(count + 1));
    expect(timers.where((t) => t.isActive), isEmpty);
    emit(state.copyWith(position: const Duration(seconds: 20)));
    fireAll(PlaybackSessionSaver.positionInterval);
    expect(file.saves, hasLength(count + 1));
  });

  test('a pause saves the position of the last tick', () {
    emit(state.copyWith(playing: true));
    emit(state.copyWith(position: const Duration(seconds: 42)));
    emit(state.copyWith(playing: false));

    expect(file.saves.single.position, const Duration(seconds: 42));
  });

  test('ticks while paused are ignored, a seek is saved at once', () {
    emit(state.copyWith(position: const Duration(seconds: 7)));
    expect(file.saves, isEmpty);

    emit(state.copyWith(position: const Duration(seconds: 30)));
    saver.onSeeked(const Duration(seconds: 30));

    expect(file.saves.single.position, const Duration(seconds: 30));
  });

  test('a track change saves at once from its start', () {
    emit(state.copyWith(playing: true));
    emit(state.copyWith(position: const Duration(seconds: 50)));
    emit(
      state.copyWith(queue: queue.copyWith(index: 2), position: Duration.zero),
    );

    expect(file.saves.single.index, 2);
    expect(file.saves.single.position, Duration.zero);
  });

  test('stopping keeps the track and saves position zero', () {
    emit(state.copyWith(playing: true));
    emit(state.copyWith(position: const Duration(seconds: 50)));
    emit(state.copyWith(playing: false, stopped: true));

    expect(file.saves.last.index, 1);
    expect(file.saves.last.position, Duration.zero);
  });

  test('an equal snapshot is not written again', () {
    emit(state.copyWith(volume: 50));
    fireAll(PlaybackSessionSaver.coalesceDelay);
    emit(state.copyWith(volume: 60));
    emit(state.copyWith(volume: 50));
    fireAll(PlaybackSessionSaver.coalesceDelay);

    expect(file.saves, hasLength(1));
  });

  test('a failed write is written again by the next save', () async {
    file.succeeds = false;
    emit(state.copyWith(playing: true));
    emit(state.copyWith(position: const Duration(seconds: 42)));
    emit(state.copyWith(playing: false));
    expect(file.saves, hasLength(1));
    await Future<void>.delayed(Duration.zero);

    file.succeeds = true;
    saver.onSeeked(const Duration(seconds: 42));
    expect(file.saves, hasLength(2));
    expect(file.saves.last, file.saves.first);
  });

  test('dispose writes a snapshot whose write failed', () async {
    file.succeeds = false;
    emit(state.copyWith(playing: true));
    emit(state.copyWith(playing: false));
    await Future<void>.delayed(Duration.zero);

    file.succeeds = true;
    saver.dispose();

    expect(file.saves, hasLength(2));
    expect(file.saves.last, file.saves.first);
  });

  test('a written snapshot is not written again by dispose', () async {
    emit(state.copyWith(playing: true));
    emit(state.copyWith(playing: false));
    await Future<void>.delayed(Duration.zero);

    saver.dispose();

    expect(file.saves, hasLength(1));
  });

  group('a restored session', () {
    final restored = PlaybackSession.fromState(
      PlayerState(queue: queue, volume: 40),
      position: const Duration(seconds: 83),
    );

    setUp(() {
      saver = makeSaver(initial: restored, frozen: true);
      state = PlayerState(
        queue: queue,
        volume: 40,
        position: const Duration(seconds: 83),
      );
      saver.onState(null, state);
    });

    test('writes nothing while frozen', () {
      emit(state.copyWith(queue: queue.copyWith(index: 2)));
      emit(state.copyWith(volume: 10));
      fireAll(PlaybackSessionSaver.coalesceDelay);
      saver.dispose();

      expect(file.saves, isEmpty);
    });

    test('a stray zero tick after the paused open keeps the position', () {
      emit(state.copyWith(position: Duration.zero));
      emit(state.copyWith(playing: false));
      saver.unfreeze();
      fireAll(PlaybackSessionSaver.coalesceDelay);
      expect(file.saves, isEmpty);

      emit(state.copyWith(volume: 70));
      fireAll(PlaybackSessionSaver.coalesceDelay);
      expect(file.saves.single.position, const Duration(seconds: 83));
      expect(file.saves.single.volume, 70);
    });

    test('saves what changed while frozen once unfrozen', () {
      emit(state.copyWith(queue: queue.copyWith(index: 2)));
      saver.unfreeze();
      fireAll(PlaybackSessionSaver.coalesceDelay);

      expect(file.saves.single.index, 2);
    });
  });

  test('dispose writes the pending snapshot and stops the timers', () {
    emit(state.copyWith(volume: 30));
    emit(state.copyWith(playing: true));
    saver.dispose();

    expect(file.saves.single.volume, 30);
    expect(timers.where((t) => t.isActive), isEmpty);
    emit(state.copyWith(volume: 20));
    saver.onSeeked(Duration.zero);
    expect(file.saves, hasLength(1));
  });
}
