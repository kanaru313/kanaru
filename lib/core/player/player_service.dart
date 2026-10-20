import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_backend.dart';
import 'media_kit_backend.dart';
import 'play_queue.dart';
import 'playback_error.dart';
import 'player_state.dart';
import 'repeat_mode.dart';
import 'session/playback_session_provider.dart';
import 'session/playback_session_saver.dart';
import 'track.dart';

part 'player_queue_commands.dart';
part 'player_session_commands.dart';
part 'player_settings_commands.dart';
part 'player_transport_commands.dart';

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
class PlayerService extends Notifier<PlayerState>
    with
        _PlayerSettingsCommands,
        _PlayerTransportCommands,
        _PlayerQueueCommands,
        _PlayerSessionCommands {
  PlayerService({this._random});

  @override
  final Random? _random;
  @override
  late AudioBackend _backend;
  late StreamController<PlaybackError> _errors;

  /// Entries (indexes into `PlayQueue.original`) handed to the engine as
  /// "next" since it last started or advanced, oldest first. The engine can
  /// still move on to an older one while a newer `setNext` is in flight.
  @override
  final _handedNext = <int>[];

  /// Playback stopped after the last track; play starts the queue over.
  @override
  bool _ended = false;

  /// Broken tracks in a row, so a queue of broken files is not retried
  /// forever. Cleared by a track that loads and by anything the user plays.
  @override
  int _failuresInRow = 0;

  /// What was last asked for: playing, or paused. A track that fails moves
  /// on in that state, so a track loaded paused (or paused while it was
  /// still loading) never starts playing on its own. Kept apart from
  /// `state.playing`, which the engine may turn off on its own before it
  /// reports that it stopped.
  @override
  bool _wantsPlaying = false;

  /// Every track in the queue failed since the last one that played.
  @override
  bool get _allFailed => _failuresInRow >= state.queue.order.length;

  /// How close to the end the last tick must be, and how close to the start
  /// the next one, for it to count as repeat one starting the track over.
  static const _loopJump = Duration(seconds: 2);

  @override
  late StreamController<Duration> _seeked;

  /// Position of the last engine tick, to tell repeat one looping the track
  /// from a tick that merely arrives out of order.
  @override
  Duration _lastTick = Duration.zero;

  /// Tracks the engine could not play, one event per track.
  Stream<PlaybackError> get errors => _errors.stream;

  /// The playback position jumped: once per [seek], and when repeat one
  /// loops the track (to zero). Plain progress never shows up here.
  Stream<Duration> get seeked => _seeked.stream;

  @override
  PlayerState build() {
    _backend = ref.watch(audioBackendProvider);
    _errors = StreamController.broadcast();
    _seeked = StreamController.broadcast();
    final subscriptions = [
      _backend.advanced.listen(_onAdvanced),
      _backend.playing.listen((v) => state = state.copyWith(playing: v)),
      _backend.completed.listen((done) {
        if (done) _onCompleted();
      }),
      _backend.position.listen(_onPosition),
      _backend.duration.listen((v) {
        if (v > Duration.zero) {
          _failuresInRow = 0;
          _sessionTrackLoaded();
        }
        state = state.copyWith(duration: v);
      }),
      _backend.failed.listen(_onFailed),
    ];
    ref.onDispose(() {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
      _errors.close();
      _seeked.close();
    });
    return _startSession();
  }

  void _onPosition(Duration position) {
    // Only a tick from the end of a known-length track can be followed by a
    // loop; stale ticks after a track change, seek or stop never qualify.
    final looped =
        state.queue.repeat == RepeatMode.one &&
        state.duration > Duration.zero &&
        state.duration - _lastTick < _loopJump &&
        position < _loopJump;
    _lastTick = position;
    state = state.copyWith(position: position);
    if (looped) _seeked.add(Duration.zero);
  }

  /// The engine stopped. With a track still to come, the current one failed
  /// or the engine ran out of tracks before it got the next one: go on.
  void _onCompleted() {
    final next = state.queue.nextIndex;
    if (next != null && !_allFailed) {
      _play(next, play: _wantsPlaying);
      return;
    }
    _ended = true;
    state = state.copyWith(playing: false, stopped: true);
  }

  void _onFailed(PlaybackError error) {
    _failuresInRow++;
    _errors.add(error);
  }

  @override
  void _userActed() => _sessionUserActed();

  /// Hands the engine the track that follows the current one.
  @override
  Future<void> _queueNext() {
    final queue = state.queue;
    final next = queue.nextIndex;
    if (next != null) {
      final entry = queue.order[next];
      // Edits that keep the same next track would otherwise pile it up.
      if (_handedNext.lastOrNull != entry) _handedNext.add(entry);
    }
    return _backend.setNext(next == null ? null : queue.tracks[next]);
  }

  /// Loads the track at [index], playing or paused, from [start].
  @override
  Future<void> _play(
    int index, {
    bool play = true,
    Duration start = Duration.zero,
  }) async {
    final queue = state.queue.copyWith(index: index);
    if (index < 0 || index >= queue.order.length) return;
    _ended = false;
    _wantsPlaying = play;
    final next = queue.nextIndex;
    _handedNext.clear();
    if (next != null) _handedNext.add(queue.order[next]);
    // A track loaded without playing is paused, not stopped.
    state = state.copyWith(
      queue: queue,
      playing: play,
      stopped: false,
      position: start,
      duration: Duration.zero,
    );
    _lastTick = start;
    await _backend.open(
      queue.tracks[index],
      next: next == null ? null : queue.tracks[next],
      play: play,
      start: start,
    );
  }
}
