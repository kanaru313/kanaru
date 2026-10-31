part of 'player_service.dart';

/// The player's side of the sleep timer: "stop after the current track" and
/// the sleep fade-out. Stopping means pausing: the queue stays, and the
/// track after the current one waits paused at its start.
///
/// While the stop is on, the engine is never handed a next track, so it
/// stops by itself when the current one ends (`_onCompleted` then loads the
/// next one paused). Repeat one never ends a track: the looped track rests
/// paused at 0 instead (`_onLooped`). If the engine moved on to a next track
/// handed before the stop was turned on (its withdrawal was still on the
/// way), that track rests paused at 0 as soon as the move is reported.
///
/// [trackEnds] counts the tracks the engine finishes by itself.
///
/// Each stop clears the flag and is announced once on [sleepStops]. A
/// provider rebuild turns the flag off and makes a new stream.
mixin _PlayerSleepStop on Notifier<PlayerState> {
  AudioBackend get _backend;
  bool get _ended;
  int get _failuresInRow;
  set _wantsPlaying(bool wanted);
  void _settleFade();
  PlayPauseFader get _fades;
  PlayPauseFader? get _fadesNow;
  Future<void> _queueNext();
  void _followEngine(String what, Future<void> Function() action);

  bool _stopAfterCurrent = false;
  late StreamController<void> _sleepStops;
  late StreamController<void> _trackEnds;

  /// Playback pauses once the current track ends.
  bool get stopAfterCurrent => _stopAfterCurrent;

  /// One event per stop made because [stopAfterCurrent] was on, sent
  /// synchronously before the player pauses or loads the next track. The
  /// flag is already off when a listener hears it. A new stream after each
  /// provider rebuild, so a listener must subscribe again.
  Stream<void> get sleepStops => _sleepStops.stream;

  /// One event per track the engine finished by itself: moved on, ran out
  /// or looped (repeat one, counted repeat). Not for a failed track, not
  /// for a track ended by a sleep stop (see [sleepStops]) and never for
  /// skip, previous, jump, seek or open. Sent synchronously after [state]
  /// shows what follows. A new stream after each provider rebuild.
  Stream<void> get trackEnds => _trackEnds.stream;

  /// Turns the stop after the current track on or off. The engine's next
  /// track is handed again at once: withdrawn when turned on, given back
  /// when turned off.
  void setStopAfterCurrent(bool stop) {
    if (stop == _stopAfterCurrent || !ref.mounted) return;
    _stopAfterCurrent = stop;
    if (state.queue.isEmpty || _ended) return;
    _followEngine(
      stop ? 'withdraw the next track' : 'queue the next track',
      _queueNext,
    );
  }

  /// Turns the stop off without reading the player's state, for a caller
  /// that may not use providers right now (a provider being disposed). The
  /// next track is handed again in a microtask, unless the stop was turned
  /// on again by then.
  void releaseStopAfterCurrent() {
    if (!_stopAfterCurrent) return;
    _stopAfterCurrent = false;
    scheduleMicrotask(() {
      if (!ref.mounted || _stopAfterCurrent) return;
      if (state.queue.isEmpty || _ended) return;
      _followEngine('queue the next track', _queueNext);
    });
  }

  /// Ramps the engine's volume down to silence over [length] while it keeps
  /// playing; [PlayerState] does not change (see
  /// [PlayPauseFader.fadeOutForSleep]). A [pause] at the end pauses and
  /// sends the user's volume back.
  void fadeOutForSleep(Duration length) {
    if (ref.mounted) _fades.fadeOutForSleep(length);
  }

  /// Ends a sleep fade-out, sending the user's volume back; leaves the
  /// play/pause fades alone.
  void endSleepFade() => _fadesNow?.endSleepFade();

  /// A sleep fade-out is running or left the engine's volume lowered.
  bool get sleepFading => _fadesNow?.sleepFading ?? false;

  /// Call once per build, before the engine's events are listened to.
  void _startSleepStop() {
    _stopAfterCurrent = false;
    final stops = _sleepStops = StreamController.broadcast(sync: true);
    ref.onDispose(stops.close);
    final ends = _trackEnds = StreamController.broadcast(sync: true);
    ref.onDispose(ends.close);
  }

  /// Clears the flag and announces the stop. False when the flag was off.
  bool _takeSleepStop() {
    if (!_stopAfterCurrent) return false;
    _stopAfterCurrent = false;
    if (!_sleepStops.isClosed) _sleepStops.add(null);
    return true;
  }

  /// The engine moved on by itself to [track], which [follow] handles as
  /// usual. With the stop on, the engine took a next track handed before
  /// the stop: the move is followed (and the track after it handed), then
  /// the new track rests at its start.
  void _advanceWithSleepStop(Track track, void Function(Track) follow) {
    final stop = _takeSleepStop();
    final failed = _failuresInRow > 0;
    follow(track);
    if (stop) {
      _restAtStart();
    } else if (!failed) {
      _announceTrackEnd();
    }
  }

  /// A track ended by the engine's own doing; see [trackEnds].
  void _announceTrackEnd() {
    if (!_trackEnds.isClosed) _trackEnds.add(null);
  }

  /// Pauses the current track at 0, like [stop] does but without marking
  /// playback stopped and without announcing a seek: the engine started the
  /// track over (or moved on to it) by itself. A fade under way settles
  /// first.
  void _restAtStart() {
    _settleFade();
    _wantsPlaying = false;
    state = state.copyWith(playing: false, position: Duration.zero);
    _followEngine('pause after the current track', () async {
      await _backend.pause();
      await _backend.seek(Duration.zero);
    });
  }
}
