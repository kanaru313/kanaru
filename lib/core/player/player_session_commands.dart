part of 'player_service.dart';

/// Bringing the last playback session back on launch, paused, and saving it
/// while the app runs (see [PlaybackSessionSaver] for when it writes).
mixin _PlayerSessionCommands on Notifier<PlayerState> {
  AudioBackend get _backend;
  StreamController<Duration> get _seeked;
  bool get _wantsPlaying;
  Future<void> _play(
    int index, {
    bool play = true,
    Duration start = Duration.zero,
  });

  PlaybackSessionSaver? _saver;

  /// Identifies the current build, so a restore scheduled by an older one
  /// does nothing.
  Object? _sessionBuild;

  /// Whether a track was handed to the engine since this build. A track the
  /// user opened before the restore ran wins over the restored one.
  bool _openedSinceBuild = false;

  /// Loads the saved session and sets up saving. Returns the state the
  /// player starts in: the restored queue and volume, paused. The engine is
  /// set up a microtask later, so the first frame and the first MPRIS reply
  /// already show the restored session.
  PlayerState _startSession() {
    _sessionBuild = null;
    _openedSinceBuild = false;
    _saver = null;
    final file = ref.watch(playbackSessionFileProvider);
    if (file == null) return PlayerState();
    final session = file.load();
    final saver = PlaybackSessionSaver(
      file,
      initial: session,
      frozen: session?.hasTrack ?? false,
    );
    _saver = saver;
    listenSelf(saver.onState);
    final seeks = _seeked.stream.listen(saver.onSeeked);
    ref.onDispose(() {
      seeks.cancel();
      saver.dispose();
    });
    if (session == null) return PlayerState();

    final queue = session.toQueue();
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
    unawaited(_backend.setRepeat(state.queue.repeat));
    if (_openedSinceBuild || state.queue.isEmpty) return;
    unawaited(
      _play(state.queue.index, play: _wantsPlaying, start: state.position),
    );
  }

  /// A track loaded: the restored session works, so saving can go on.
  void _sessionTrackLoaded() => _saver?.unfreeze();

  /// The user (or an external controller) did something: saving goes on.
  void _sessionUserActed() => _saver?.unfreeze();
}
