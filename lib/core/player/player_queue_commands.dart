part of 'player_service.dart';

/// Editing the queue while it plays, and following the engine when it moves
/// on by itself. The engine only knows `[current, next]`, so an edit is a new
/// Dart queue plus a fresh `setNext`; only removing the playing track makes
/// the engine open something else.
mixin _PlayerQueueCommands on Notifier<PlayerState> {
  AudioBackend get _backend;
  set _ended(bool ended);
  set _lastTick(Duration position);
  set _failuresInRow(int count);
  bool get _allFailed;
  bool get _wantsPlaying;
  set _wantsPlaying(bool wanted);
  List<int> get _handedNext;
  Future<void> _queueNext();
  Future<void> _play(int index, {bool play = true});
  void _userActed();

  /// Moves the track at play position [from] to [to]. The playing track is
  /// never interrupted, even when it is the one dragged.
  Future<void> moveTrack(int from, int to) async {
    final moved = state.queue.move(from, to);
    if (identical(moved, state.queue)) return;
    _userActed();
    _failuresInRow = 0;
    state = state.copyWith(queue: moved);
    await _queueNext();
  }

  /// Removes the track at play position [at]. Removing the playing track
  /// plays whatever slides into its place (kept paused when paused); at the
  /// end of the queue playback stops like it does when the queue runs out.
  Future<void> removeTrack(int at) async {
    final queue = state.queue;
    if (at < 0 || at >= queue.order.length) return;
    _userActed();
    _failuresInRow = 0;
    final rest = queue.removeAt(at);
    if (rest.isEmpty) return _clearPlayback();
    if (at != queue.index) {
      state = state.copyWith(queue: rest);
      return _queueNext();
    }
    final pastEnd = at == queue.order.length - 1;
    if (pastEnd && queue.repeat != RepeatMode.all) {
      _markStopped(ended: true, queue: rest);
      return _backend.stop();
    }
    state = state.copyWith(queue: rest);
    await _play(rest.index, play: _wantsPlaying);
  }

  /// Removes every track but the playing one, without interrupting it.
  /// Removing that one too is what empties the queue.
  Future<void> clearQueue() async {
    if (state.queue.isEmpty) return;
    _userActed();
    _failuresInRow = 0;
    state = state.copyWith(queue: state.queue.keepOnlyCurrent());
    await _queueNext();
  }

  /// Nothing left to play: stops the engine and keeps shuffle and repeat.
  Future<void> _clearPlayback() {
    final queue = state.queue;
    _markStopped(
      ended: false,
      queue: PlayQueue(shuffled: queue.shuffled, repeat: queue.repeat),
    );
    return _backend.stop();
  }

  /// Playback stopped for good: nothing is wanted playing and the engine's
  /// next-track bookkeeping is void. [ended] means the queue ran out (play
  /// restarts it); [resetPosition] false keeps the finished track to seek back
  /// into. [queue] swaps the queue in the same update. Leaves the engine alone.
  void _markStopped({
    required bool ended,
    bool resetPosition = true,
    PlayQueue? queue,
  }) {
    _ended = ended;
    _wantsPlaying = false;
    _handedNext.clear();
    _lastTick = Duration.zero;
    state = state.copyWith(
      queue: queue ?? state.queue,
      playing: false,
      stopped: true,
      position: resetPosition ? Duration.zero : state.position,
      duration: resetPosition ? Duration.zero : state.duration,
    );
  }

  /// Runs an engine call made while following the engine on its own, where
  /// nobody awaits the result: a failure is logged instead of escaping as an
  /// uncaught error. Only an [Exception] (an engine failure) is caught; an
  /// [Error] is a bug and still reaches the zone.
  void _followEngine(String what, Future<void> Function() action) {
    unawaited(
      Future.sync(action).catchError((Object error, StackTrace stack) {
        _log.warning('Could not $what', error, stack);
      }, test: (error) => error is Exception),
    );
  }

  void _onAdvanced(Track track) {
    final queue = state.queue;
    if (queue.isEmpty) return;
    final index = _resolveAdvanced(queue, track);
    if (index == null) {
      _followEngine('carry on after a removed track', _advancedToRemoved);
      return;
    }
    state = state.copyWith(
      queue: queue.copyWith(index: index),
      position: Duration.zero,
      duration: Duration.zero,
    );
    _lastTick = Duration.zero;
    _handedNext.clear();
    // The engine skips broken files on its own; with repeat all it would go
    // round the queue forever. Queuing nothing lets it stop after this one.
    if (_allFailed) {
      _followEngine('stop queuing tracks', () => _backend.setNext(null));
    } else {
      _followEngine('queue the next track', _queueNext);
    }
  }

  /// Play position of the track the engine moved on to. Matches the entries
  /// that were handed over first, newest first (the engine may still take an
  /// older one, and a track dragged elsewhere keeps playing); then by file,
  /// starting after the current track so a duplicate earlier in the queue is
  /// not picked. `null` when the track was removed meanwhile.
  int? _resolveAdvanced(PlayQueue queue, Track track) {
    for (final entry in _handedNext.reversed) {
      final at = queue.order.indexOf(entry);
      if (at >= 0 && queue.original[entry] == track) return at;
    }
    final length = queue.order.length;
    for (var step = 1; step <= length; step++) {
      final at = (queue.index + step) % length;
      if (queue.trackAt(at) == track) return at;
    }
    return null;
  }

  /// The engine moved on to a track that was removed after it was handed
  /// over: carry on with the queue as it is now, playing or paused as asked
  /// last, or stop when it ran out.
  Future<void> _advancedToRemoved() {
    final next = state.queue.nextIndex;
    if (next != null) return _play(next, play: _wantsPlaying);
    _markStopped(ended: true);
    return _backend.stop();
  }
}
