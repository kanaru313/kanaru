part of 'player_service.dart';

/// Bringing the last playback session back on launch, paused, with the
/// "play next" tracks still to come, and saving it while the app runs (see
/// [PlaybackSessionSaver] for when it writes).
mixin _PlayerSessionCommands on _PlayerCore {
  /// Loads the saved session and sets up saving. Returns the state the
  /// player starts in: the restored queue and volume, paused. The engine is
  /// set up a microtask later, so the first frame and the first MPRIS reply
  /// already show the restored session.
  PlayerState _startSession() {
    final file = ref.watch(playbackSessionFileProvider);
    if (file == null) {
      _restoredExtras ??= const {};
      return PlayerState();
    }
    var session = file.load();
    if (_restoredExtras == null) {
      _restoredExtras = session?.extras ?? const {};
      _sessionExtras = _restoredExtras!;
    }
    final queue = session?.toQueue();
    // A position at or past the saved length would make the engine reach the
    // end at once and move on to the next track.
    final length = queue?.current?.duration;
    if (session != null &&
        length != null &&
        length > Duration.zero &&
        session.position >= length) {
      session = session.withPosition(Duration.zero);
    }
    final saver = PlaybackSessionSaver(
      file,
      initial: session,
      frozen: session?.hasTrack ?? false,
      upNext: () => _upNext,
      extras: () => _sessionExtras,
    );
    _saver = saver;
    listenSelf(saver.onState);
    final seeks = _seeked.stream.listen(saver.onSeeked);
    ref.onDispose(() {
      seeks.cancel();
      saver.dispose();
    });
    if (session == null || queue == null) return PlayerState();
    // "Play next" tracks still to come stay marked, so the next "play next"
    // goes behind them as before the restart.
    _upNext.addAll(session.restoredUpNext());

    final token = Object();
    _sessionBuild = token;
    Future.microtask(() => _restoreEngine(token));
    return PlayerState(
      queue: queue,
      position: session.hasTrack ? session.position : Duration.zero,
      volume: session.volume,
      volumeBeforeMute: session.volumeBeforeMute,
    );
  }

  /// Hands the restored session to the engine: volume and repeat (the
  /// engine starts at its own defaults), then the current track at the
  /// saved position, paused. Commands that ran first are kept: the volume,
  /// queue and position they set are what gets loaded, playing when the user
  /// pressed play; a track the user opened is left alone.
  void _restoreEngine(Object token) {
    if (!ref.mounted || !identical(_sessionBuild, token)) return;
    _sessionBuild = null;
    unawaited(_backend.setVolume(state.volume));
    // A counted repeat armed before this ran keeps the engine looping.
    unawaited(
      _backend.setRepeat(
        state.repeatTimes > 0 ? RepeatMode.one : state.queue.repeat,
      ),
    );
    if (_openedSinceBuild || state.queue.isEmpty) return;
    if (state.stopped) {
      // A stop made before this ran stays: the track is loaded paused at the
      // start, the engine state `stop()` leaves. A queue that already ran out
      // loads nothing; play restarts it.
      if (_intent == _PlayIntent.ended) return;
      unawaited(_play(state.queue.index, play: false));
      // `_play` marks the player as not stopped before its first await.
      state = state.copyWith(stopped: true);
      return;
    }
    unawaited(
      _play(
        state.queue.index,
        play: _intent == _PlayIntent.playing,
        start: state.position,
      ),
    );
  }

  /// Keeps [json] under [key] with the session, saved and restored as it is
  /// (null removes the key). A value that is not JSON is refused and logged
  /// by key only, because one would make every session write fail.
  void setSessionExtra(String key, Object? json) {
    final next = Map<String, Object?>.of(_sessionExtras);
    if (json == null) {
      next.remove(key);
    } else {
      // A plain copy: the caller's object may be mutated later, or hold
      // something that cannot cross to the writer isolate.
      final Object? copy;
      try {
        copy = _jsonCopy(json);
      } on Object {
        _log.warning('Session extra "$key" is not JSON; not stored');
        return;
      }
      next[key] = copy;
    }
    _sessionExtras = Map.unmodifiable(next);
    _saver?.onExtrasChanged();
  }

  /// The value [key] had in the session loaded at the first build, or null.
  /// A copy, so callers cannot change what is kept.
  Object? restoredSessionExtra(String key) => _jsonCopy(_restoredExtras?[key]);

  static Object? _jsonCopy(Object? value) => jsonDecode(jsonEncode(value));

  /// Writes the latest session now and waits for the disk, for the app's exit.
  Future<void> flushSession() => _saver?.flush() ?? Future.value();

  /// A track loaded: the restored session works, so saving can go on.
  void _sessionTrackLoaded() => _saver?.unfreeze();
}
