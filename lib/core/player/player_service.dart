import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_backend.dart';
import 'media_kit_backend.dart';
import 'play_queue.dart';
import 'playback_error.dart';
import 'player_state.dart';
import 'repeat_mode.dart';
import 'track.dart';

/// Audio engine for the app session. Tests override it with a fake so they
/// never load libmpv.
final audioBackendProvider = Provider<AudioBackend>((ref) {
  final backend = MediaKitBackend();
  ref.onDispose(backend.dispose);
  return backend;
});

final playerServiceProvider = NotifierProvider<PlayerService, PlayerState>(
  PlayerService.new,
);

/// Owns the play queue and drives the [AudioBackend] from it: the engine
/// gets the current track plus the one that should follow, and reports back
/// when it moved on to that one by itself.
class PlayerService extends Notifier<PlayerState> {
  PlayerService({this._random});

  final Random? _random;
  late AudioBackend _backend;
  late StreamController<PlaybackError> _errors;

  /// Queue position of the track handed to the engine as "next".
  int? _nextIndex;

  /// Playback stopped after the last track; play starts the queue over.
  bool _ended = false;

  /// Broken tracks in a row, so a queue of broken files is not retried
  /// forever. Cleared by a track that loads and by anything the user plays.
  int _failuresInRow = 0;

  /// Every track in the queue failed since the last one that played.
  bool get _allFailed => _failuresInRow >= state.queue.order.length;

  /// Tracks the engine could not play, one event per track.
  Stream<PlaybackError> get errors => _errors.stream;

  @override
  PlayerState build() {
    _backend = ref.watch(audioBackendProvider);
    _errors = StreamController.broadcast();
    final subscriptions = [
      _backend.advanced.listen(_onAdvanced),
      _backend.playing.listen((v) => state = state.copyWith(playing: v)),
      _backend.completed.listen((done) {
        if (done) _onCompleted();
      }),
      _backend.position.listen((v) => state = state.copyWith(position: v)),
      _backend.duration.listen((v) {
        if (v > Duration.zero) _failuresInRow = 0;
        state = state.copyWith(duration: v);
      }),
      _backend.volume.listen((v) => state = state.copyWith(volume: v)),
      _backend.failed.listen(_onFailed),
    ];
    ref.onDispose(() {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
      _errors.close();
    });
    return PlayerState();
  }

  void _onAdvanced(Track track) {
    final queue = state.queue;
    var index = _nextIndex;
    // The queue may have changed after the engine got its next track.
    if (index == null || index >= queue.order.length) index = -1;
    if (index < 0 || queue.tracks[index] != track) {
      index = queue.tracks.indexOf(track);
      if (index < 0) return;
    }
    state = state.copyWith(
      queue: queue.copyWith(index: index),
      position: Duration.zero,
      duration: Duration.zero,
    );
    // The engine skips broken files on its own; with repeat all it would go
    // round the queue forever. Queuing nothing lets it stop after this one.
    if (_allFailed) {
      _nextIndex = null;
      _backend.setNext(null);
    } else {
      _queueNext();
    }
  }

  /// The engine stopped. With a track still to come, the current one failed
  /// or the engine ran out of tracks before it got the next one: go on.
  void _onCompleted() {
    final next = state.queue.nextIndex;
    if (next != null && !_allFailed) {
      _play(next);
      return;
    }
    _ended = true;
    state = state.copyWith(playing: false);
  }

  void _onFailed(PlaybackError error) {
    _failuresInRow++;
    _errors.add(error);
  }

  /// Hands the engine the track that follows the current one.
  Future<void> _queueNext() {
    final queue = state.queue;
    _nextIndex = queue.nextIndex;
    final next = _nextIndex;
    return _backend.setNext(next == null ? null : queue.tracks[next]);
  }

  /// Replaces the queue with [tracks] and plays from [start]. Shuffle and
  /// repeat stay as they were.
  Future<void> openTracks(List<Track> tracks, {int start = 0}) async {
    if (tracks.isEmpty) return;
    final queue = PlayQueue.open(
      tracks,
      start,
      repeat: state.queue.repeat,
      shuffled: state.queue.shuffled,
      random: _random,
    );
    state = state.copyWith(queue: queue);
    await jump(queue.index);
  }

  /// Plays the track at [index] in play order, as picked by the user.
  Future<void> jump(int index) {
    _failuresInRow = 0;
    return _play(index);
  }

  Future<void> _play(int index) async {
    final queue = state.queue.copyWith(index: index);
    if (index < 0 || index >= queue.order.length) return;
    _ended = false;
    _nextIndex = queue.nextIndex;
    final next = _nextIndex;
    state = state.copyWith(
      queue: queue,
      playing: true,
      position: Duration.zero,
      duration: Duration.zero,
    );
    await _backend.open(
      queue.tracks[index],
      next: next == null ? null : queue.tracks[next],
    );
  }

  Future<void> playPause() async {
    if (state.queue.isEmpty) return;
    if (_ended) return jump(0);
    final play = !state.playing;
    state = state.copyWith(playing: play);
    await (play ? _backend.play() : _backend.pause());
  }

  Future<void> next() async {
    final index = state.queue.nextIndex;
    if (index != null) await jump(index);
  }

  /// Goes to the previous track; does nothing on the first one unless the
  /// whole queue repeats.
  Future<void> previous() async {
    final index = state.queue.previousIndex;
    if (index != null) await jump(index);
  }

  Future<void> seek(Duration position) async {
    if (state.queue.isEmpty) return;
    // Seeking back into a finished track resumes it rather than the queue.
    if (state.duration > Duration.zero) _ended = false;
    state = state.copyWith(position: position);
    await _backend.seek(position);
  }

  /// Seeks relative to the current position, kept inside the track.
  Future<void> seekBy(Duration offset) {
    var target = state.position + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (state.duration > Duration.zero && target > state.duration) {
      target = state.duration;
    }
    return seek(target);
  }

  /// Sets the volume (0–100). Changing it while muted unmutes.
  Future<void> setVolume(double volume) async {
    final value = volume.clamp(0, 100).toDouble();
    state = state.copyWith(volume: value, volumeBeforeMute: () => null);
    await _backend.setVolume(value);
  }

  Future<void> toggleMute() async {
    final restore = state.volumeBeforeMute;
    if (restore != null) {
      await setVolume(restore);
    } else {
      final before = state.volume;
      state = state.copyWith(volume: 0, volumeBeforeMute: () => before);
      await _backend.setVolume(0);
    }
  }

  /// Turns shuffle on or off. The current track keeps playing; only the
  /// engine's next track changes.
  Future<void> toggleShuffle() async {
    final current = state.queue;
    state = state.copyWith(
      queue: current.shuffled ? current.unshuffle() : current.shuffle(_random),
    );
    if (!state.queue.isEmpty) await _queueNext();
  }

  /// Off → all → one → off.
  Future<void> cycleRepeat() async {
    final repeat = switch (state.queue.repeat) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    state = state.copyWith(queue: state.queue.copyWith(repeat: repeat));
    await _backend.setRepeat(repeat);
    if (!state.queue.isEmpty) await _queueNext();
  }
}
