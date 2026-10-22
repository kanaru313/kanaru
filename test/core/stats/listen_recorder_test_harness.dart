import 'package:drift/drift.dart' show Value, ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:kanaru/core/database/library_database.dart' hide Track;
import 'package:kanaru/core/player/play_queue.dart';
import 'package:kanaru/core/player/player_state.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/stats/listen_recorder.dart';

import '../database/library_database_test.dart' show track;
import 'gated_query_interceptor.dart';

/// Library tracks the recorder tests listen to.
final trackA = _song('a', const Duration(minutes: 3));
final trackB = _song('b', const Duration(minutes: 10));
final trackC = _song('c', const Duration(minutes: 2));
final trackShort = _song('short', const Duration(seconds: 25));
final trackLoop = _song('loop', const Duration(seconds: 40));
final trackUnknown = _song('unknown', null);

/// Not in the library.
final stranger = Track(
  uri: '/elsewhere/x.flac',
  title: 'x',
  duration: const Duration(minutes: 3),
);

Track _song(String name, Duration? duration) =>
    Track(uri: '/music/$name.mp3', title: name, duration: duration);

/// In-memory library holding [libraryTracks], with a [GatedQueryInterceptor]
/// on its connection.
Future<(LibraryDatabase, GatedQueryInterceptor)> openLibrary() async {
  final gate = GatedQueryInterceptor();
  final db = LibraryDatabase(NativeDatabase.memory().interceptWith(gate));
  final roots = await db.addRoots(['/music'], now: 1);
  await db.upsertTracks([
    for (final t in [
      trackA,
      trackB,
      trackC,
      trackShort,
      trackLoop,
      trackUnknown,
    ])
      track(
        roots.single,
        t.uri,
        title: t.title,
      ).copyWith(durationMs: Value(t.duration?.inMilliseconds)),
  ]);
  gate.statements.clear();
  return (db, gate);
}

/// Wall and monotonic clock moving together, as one fake.
class FakeListenClock {
  Duration elapsed = Duration.zero;
  DateTime now = DateTime.utc(2026, 10, 22, 12);

  void advance(Duration by) {
    elapsed += by;
    now = now.add(by);
  }

  ListenClock get clock => (now: () => now, elapsed: () => elapsed);
}

Duration seconds(num value) => Duration(milliseconds: (value * 1000).round());

/// Plays the part of the player: publishes the states a recorder would see.
class PlayerSim {
  PlayerSim(this.recorder, this.time);

  final ListenRecorder recorder;
  final FakeListenClock time;
  Track track = trackA;
  int marker = 0;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool playing = true;
  bool stopped = false;

  void emit() => recorder.onState(
    null,
    PlayerState(
      queue: PlayQueue(original: [track]),
      playing: playing,
      stopped: stopped,
      position: position,
      duration: duration,
      playthrough: marker,
    ),
  );

  /// A fresh start of [next] (new marker), playing unless [play] is false.
  void open(
    Track next, {
    bool play = true,
    Duration at = Duration.zero,
    Duration? engineDuration,
  }) {
    track = next;
    marker++;
    position = at;
    playing = play;
    stopped = false;
    duration = engineDuration ?? next.duration ?? Duration.zero;
    emit();
  }

  /// Listens for [length] seconds in [step]-second ticks.
  void listen(num length, {num step = 1}) {
    for (var t = step; t <= length + 1e-9; t += step) {
      time.advance(seconds(step));
      position += seconds(step);
      emit();
    }
  }

  /// Time passes with nothing playing or moving.
  void wait(Duration by) {
    time.advance(by);
    emit();
  }

  /// A user seek: the position jumps at once, the clock hardly moves.
  void seek(Duration to) {
    time.advance(seconds(0.1));
    position = to;
    emit();
  }

  void pause() {
    playing = false;
    emit();
  }

  void resume() {
    playing = true;
    stopped = false;
    emit();
  }

  void stop() {
    stopped = true;
    playing = false;
    position = Duration.zero;
    emit();
  }
}
