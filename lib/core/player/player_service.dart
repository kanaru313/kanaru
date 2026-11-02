import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/library_startup.dart';
import '../settings/settings_provider.dart';
import 'album_run_lookup.dart';
import 'audio_backend.dart';
import 'audio_output_devices_provider.dart';
import 'media_kit_backend.dart';
import 'output_device_sync.dart';
import 'play_queue.dart';
import 'play_queue_pass.dart';
import 'playback_error.dart';
import 'player_state.dart';
import 'repeat_mode.dart';
import 'replay_gain_sync.dart';
import 'session/playback_session_provider.dart';
import 'session/playback_session_saver.dart';
import 'track.dart';

part 'player_audio_output.dart';
part 'player_core.dart';
part 'player_queue_commands.dart';
part 'player_session_commands.dart';
part 'player_settings_commands.dart';
part 'player_transport_commands.dart';
part 'sleep_timer_stop_after_current.dart';

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
class PlayerService extends _PlayerCore
    with
        _PlayerAudioOutput,
        _PlayerSettingsCommands,
        _PlayerTransportCommands,
        _PlayerQueueCommands,
        _PlayerSessionCommands,
        _PlayerSleepStop {
  PlayerService({Random? random}) : super(random);

  late StreamController<PlaybackError> _errors;

  /// Tracks the engine could not play, one event per track.
  Stream<PlaybackError> get errors => _errors.stream;

  /// The playback position jumped: once per [seek], and when repeat one
  /// loops the track (to zero). Plain progress never shows up here.
  Stream<Duration> get seeked => _seeked.stream;

  /// The queue the user replaced, once per open or open shuffled that swaps
  /// out a queue with at least one track, and once per clear queue (with the
  /// queue as it was before the clear). `state.queue` already holds the new
  /// queue when a listener hears of it, but a later open may have landed in
  /// between, so it is not the replacement of that event. Opening the same
  /// tracks again still counts as a replacement. Restoring the last
  /// session, play next, add to queue, the engine moving on, repeat, shuffle
  /// and other queue edits never show up here. The service makes a new
  /// stream when its provider rebuilds, so a listener must subscribe again.
  Stream<PlayQueue> get replacedQueues => _replacedQueues.stream;

  @override
  PlayerState build() {
    _resetForBuild();
    _backend = ref.watch(audioBackendProvider);
    _errors = StreamController.broadcast();
    _seeked = StreamController.broadcast();
    _replacedQueues = StreamController.broadcast();
    _startSleepStop();
    final subscriptions = [
      _backend.advanced.listen(
        (track) => _advanceWithSleepStop(track, _onAdvanced),
      ),
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
      _replacedQueues.close();
    });
    _startAudioOutput();
    return _startSession();
  }

  void _onPosition(Duration position) {
    state = state.copyWith(position: position);
  }

  /// The engine started [track] over under repeat one or a counted repeat.
  /// A loop that was already on its way when the user changed track or
  /// repeat mode is dropped: it is not a play of what is current now. A
  /// counted repeat uses up one play per loop; at the start of the last one
  /// the engine gets the base mode back, so the track ends and playback goes
  /// on as before. A loop that is not a sleep stop is announced on
  /// `trackEnds`. A loop already in flight when a count is armed over repeat
  /// one still counts toward it (a window of a few ms).
  void _onLooped(Track track) {
    final counting = state.repeatTimes > 0;
    if ((!counting && state.queue.repeat != RepeatMode.one) ||
        state.queue.current?.uri != track.uri) {
      return;
    }
    final sleep = _takeSleepStop();
    // A sleep stop at a loop ends the count: the track rests at 0 and a
    // later play must not loop on.
    final left = counting && !sleep ? state.repeatTimes - 1 : 0;
    state = state.copyWith(
      position: Duration.zero,
      playthrough: state.playthrough + 1,
      repeatTimes: left,
    );
    _seeked.add(Duration.zero);
    if (counting && left == 0) {
      _followEngine(
        'end the counted repeat',
        () => _backend.setRepeat(state.queue.repeat),
      );
    }
    // Stop after the current track under repeat one: the engine already
    // started it over, so it rests paused at 0, with the next track that
    // the stop held back handed again.
    if (sleep) {
      _restAtStart();
      _followEngine('queue the next track', _queueNext);
    } else {
      _announceTrackEnd();
    }
  }

  /// The engine stopped. With a track still to come, the current one failed
  /// or the engine ran out of tracks before it got the next one: go on.
  /// Otherwise playback is over and nothing is wanted playing any more, so
  /// a later queue edit loads its track paused. After a stop after the
  /// current track, the next one is loaded paused. Under repeat all shuffled
  /// the last track of a pass is followed by the first of a new random order.
  /// A track that ended by itself is announced on `trackEnds` once the state
  /// shows what follows.
  void _onCompleted() {
    final next = state.queue.nextIndex;
    final sleep = _takeSleepStop();
    final counts = !sleep && _failuresInRow == 0;
    if (next != null && !_allFailed) {
      // The engine was handed no next track on the last one: the pass is
      // over, the next one is a new random order.
      if (state.queue.endsShuffledPass) _startShuffledPass();
      _followEngine(
        'continue after the engine stopped',
        () => _play(next, play: _wantsPlaying && !sleep),
      );
    } else {
      // Position and duration stay so the user can seek back into the track.
      _markStopped(ended: true, resetPosition: false);
    }
    if (counts) _announceTrackEnd();
  }

  void _onFailed(PlaybackError error) {
    _failuresInRow++;
    _errors.add(error);
  }
}
