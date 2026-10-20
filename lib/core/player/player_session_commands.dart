part of 'player_service.dart';

/// Bringing the last playback session back on launch, paused, and saving it
/// while the app runs (see [PlaybackSessionSaver] for when it writes).
mixin _PlayerSessionCommands on Notifier<PlayerState> {
  AudioBackend get _backend;
  StreamController<Duration> get _seeked;
  Future<void> _play(
    int index, {
    bool play = true,
    Duration start = Duration.zero,
  });

  PlaybackSessionSaver? _saver;

  /// Identifies the current build, so a restore scheduled by an older one
  /// does nothing.
  Object? _sessionBuild;

  /// The current build's restore of the track; `null` once it ran, or once
  /// the user did something first, which then wins.
  Object? _pendingRestore;

  /// Loads the saved session and sets up saving. Returns the state the
  /// player starts in: the restored queue and volume, paused. The engine is
  /// set up a microtask later, so the first frame and the first MPRIS reply
  /// already show the restored session.
  PlayerState _startSession() {
    _sessionBuild = null;
    _pendingRestore = null;
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
    _pendingRestore = token;
    Future.microtask(() => _restoreEngine(token, queue, session.position));
    return PlayerState(
      queue: queue,
      position: session.hasTrack ? session.position : Duration.zero,
      volume: session.volume,
      volumeBeforeMute: session.volumeBeforeMute,
    );
  }

  /// Hands the restored session to the engine: volume and repeat always
  /// (the engine starts at its own defaults), and the current track loaded
  /// paused at the saved position unless the user already played something.
  void _restoreEngine(Object token, PlayQueue restored, Duration start) {
    if (!ref.mounted || !identical(_sessionBuild, token)) return;
    unawaited(_backend.setVolume(state.volume));
    unawaited(_backend.setRepeat(state.queue.repeat));
    if (!identical(_pendingRestore, token)) return;
    _pendingRestore = null;
    if (restored.isEmpty || !identical(state.queue, restored)) return;
    unawaited(_play(restored.index, play: false, start: start));
  }

  /// A track loaded: the restored session works, so saving can go on.
  void _sessionTrackLoaded() => _saver?.unfreeze();

  /// The user (or an external controller) did something: it wins over a
  /// restore not run yet, and saving goes on.
  void _sessionUserActed() {
    _pendingRestore = null;
    _saver?.unfreeze();
  }
}
