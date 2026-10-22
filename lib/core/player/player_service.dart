import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/library_startup.dart';
import '../settings/settings_provider.dart';
import 'album_run_lookup.dart';
import 'audio_backend.dart';
import 'audio_output_devices_provider.dart';
import 'audio_output_sync.dart';
import 'media_kit_backend.dart';
import 'play_queue.dart';
import 'playback_error.dart';
import 'player_state.dart';
import 'repeat_mode.dart';
import 'session/playback_session_provider.dart';
import 'session/playback_session_saver.dart';
import 'track.dart';

part 'player_audio_output.dart';
part 'player_queue_commands.dart';
part 'player_session_commands.dart';
part 'player_settings_commands.dart';
part 'player_transport_commands.dart';

final _log = Logger('player');

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
        _PlayerAudioOutput,
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

  /// Entries put in by "play next" that have not played yet. The next
  /// "play next" goes behind those right after the current track.
  @override
  final _upNext = <int>{};

  /// How many times the user opened a queue or put tracks into it (open, open
  /// shuffled, play next, add to queue), as opposed to the engine moving on,
  /// repeat or shuffle changing, or tracks being dragged, removed or cleared.
  /// Lets a slow caller tell whether a newer pick landed while it worked.
  @override
  int _userQueueChanges = 0;
  int get userQueueChanges => _userQueueChanges;

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

  @override
  late StreamController<Duration> _seeked;

  /// Tracks the engine could not play, one event per track.
  Stream<PlaybackError> get errors => _errors.stream;

  /// The playback position jumped: once per [seek], and when repeat one
  /// loops the track (to zero). Plain progress never shows up here.
  Stream<Duration> get seeked => _seeked.stream;

  @override
  PlayerState build() {
    // Riverpod keeps this object when the provider rebuilds: what the old
    // build asked for must not leak into the new one, or the restored track
    // would start playing on its own.
    _wantsPlaying = false;
    _ended = false;
    _failuresInRow = 0;
    _handedNext.clear();
    _upNext.clear();
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
      _backend.looped.listen(_onLooped),
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
    _startAudioOutput();
    return _startSession();
  }

  void _onPosition(Duration position) {
    state = state.copyWith(position: position);
  }

  /// The engine started [track] over under repeat one. A loop that was
  /// already on its way when the user changed track or repeat mode is
  /// dropped: it is not a play of what is current now.
  void _onLooped(Track track) {
    if (state.queue.repeat != RepeatMode.one ||
        state.queue.current?.uri != track.uri) {
      return;
    }
    state = state.copyWith(
      position: Duration.zero,
      playthrough: state.playthrough + 1,
    );
    _seeked.add(Duration.zero);
  }

  /// The engine stopped. With a track still to come, the current one failed
  /// or the engine ran out of tracks before it got the next one: go on.
  /// Otherwise playback is over and nothing is wanted playing any more, so
  /// a later queue edit loads its track paused.
  void _onCompleted() {
    final next = state.queue.nextIndex;
    if (next != null && !_allFailed) {
      _followEngine(
        'continue after the engine stopped',
        () => _play(next, play: _wantsPlaying),
      );
      return;
    }
    // Position and duration stay so the user can seek back into the track.
    _markStopped(ended: true, resetPosition: false);
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
    return _backend.setNext(next == null ? null : queue.trackAt(next));
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
    _upNext.remove(queue.order[index]);
    _wantsPlaying = play;
    _openedSinceBuild = true;
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
      playthrough: state.playthrough + 1,
    );
    await _backend.open(
      queue.trackAt(index),
      next: next == null ? null : queue.trackAt(next),
      play: play,
      start: start,
    );
  }
}
