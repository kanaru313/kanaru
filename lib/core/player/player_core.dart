part of 'player_service.dart';

/// What playback is meant to do; only the core changes it, through named
/// transitions. [playing] and [paused] are what was last asked for, kept apart
/// from `state.playing`, which the engine may turn off on its own. A track
/// that fails to load or ends with more to come, removing the playing track,
/// or the engine moving onto a removed track loads the next one in that state
/// (paused after a stop after the current track), so a track loaded paused, or
/// paused while still loading, never starts on its own. [ended] means the
/// queue ran out and nothing is wanted playing: play starts the queue over,
/// while seeking back into the finished track or adding tracks (the first
/// added one loads paused) leaves it paused.
enum _PlayIntent { playing, paused, ended }

/// The state every part of the player shares, and the primitives more than
/// one part calls. The command mixins sit on this class instead of
/// re-declaring what they borrow, and [PlayerService] adds the build and the
/// engine events.
abstract class _PlayerCore extends Notifier<PlayerState> {
  _PlayerCore(this._random);

  final Random? _random;
  late AudioBackend _backend;

  /// Entries (indexes into `PlayQueue.original`) handed to the engine as
  /// "next" since it last started or advanced, oldest first. The engine can
  /// still move on to an older one while a newer `setNext` is in flight.
  final _handedNext = <int>[];

  /// Entries put in by "play next" that have not played yet. The next
  /// "play next" goes behind those right after the current track.
  final _upNext = <int>{};

  /// How many times the user opened a queue or put tracks into it (open, open
  /// shuffled, play next, add to queue), as opposed to the engine moving on,
  /// repeat or shuffle changing, or tracks being dragged, removed or cleared.
  /// Lets a slow caller tell whether a newer pick landed while it worked.
  int _userQueueChanges = 0;
  int get userQueueChanges => _userQueueChanges;

  /// Counts the tracks that really started: every `_play` and every move of
  /// the engine to the next track. Not bumped by repeat one loops or queue
  /// edits, which keep the playing track; ReplayGain follows it.
  int _turn = 0;

  /// Broken tracks in a row, so a queue of broken files is not retried
  /// forever. Cleared by a track that loads and by anything the user plays.
  int _failuresInRow = 0;

  /// What playback is meant to do; written only by the `_intend*` methods and
  /// `_resetForBuild`.
  _PlayIntent _intent = _PlayIntent.paused;

  /// Playback pauses once the current track ends (see `_PlayerSleepStop`).
  bool _stopAfterCurrent = false;

  late StreamController<Duration> _seeked;
  late StreamController<PlayQueue> _replacedQueues;

  PlaybackSessionSaver? _saver;

  /// Identifies the current build, so a restore scheduled by an older one
  /// does nothing.
  Object? _sessionBuild;

  /// Whether a track was handed to the engine since this build. A track the
  /// user opened before the restore ran wins over the restored one.
  bool _openedSinceBuild = false;

  // Fades. The core outlives a provider rebuild, so the fader is tied to the
  // build that made it through `_seeked`, which every build makes anew; that
  // build's disposal stops it without touching the engine.
  PlayPauseFader? _fader;
  StreamController<Duration>? _faderBuild;

  /// A track is loading, [play] telling whether it should start playing.
  void _intendLoad(bool play) =>
      _intent = play ? _PlayIntent.playing : _PlayIntent.paused;

  /// The user toggled play or pause. Never called once the queue ran out:
  /// `playPause` restarts the queue then.
  void _intendToggle(bool play) {
    assert(_intent != _PlayIntent.ended);
    _intent = play ? _PlayIntent.playing : _PlayIntent.paused;
  }

  /// Playback pauses or rests; an ended queue stays ended.
  void _intendPause() {
    if (_intent == _PlayIntent.playing) _intent = _PlayIntent.paused;
  }

  /// Playback stopped, [ended] when the queue ran out.
  void _intendStop({required bool ended}) =>
      _intent = ended ? _PlayIntent.ended : _PlayIntent.paused;

  /// A seek back into the finished track resumes it, paused.
  void _intendResumeFinished() {
    if (_intent == _PlayIntent.ended) _intent = _PlayIntent.paused;
  }

  /// Riverpod keeps this object when the provider rebuilds: what the old
  /// build asked for must not leak into the new one, or the restored track
  /// would start playing on its own. Called first in `build`.
  ///
  /// Left alone on purpose:
  /// - `_userQueueChanges`: callers read `userQueueChanges` before an await
  ///   and compare after it, so it only grows; a reset could make a caller
  ///   drop or keep a stale result.
  /// - `_turn`: only compared for identity by `ReplayGainSync`, which is made
  ///   anew per build, so it just keeps counting.
  /// - the fader: tied to its build through `_seeked` (see `_fadesNow`), and
  ///   the old build's disposal stops it.
  void _resetForBuild() {
    _intent = _PlayIntent.paused;
    _failuresInRow = 0;
    _handedNext.clear();
    _upNext.clear();
    _stopAfterCurrent = false;
    _sessionBuild = null;
    _openedSinceBuild = false;
    _saver = null;
  }

  /// Every track in the queue failed since the last one that played.
  bool get _allFailed => _failuresInRow >= state.queue.order.length;

  /// Announces [previous] on `replacedQueues` unless it held no track. Every
  /// command that swaps the whole queue out calls this.
  void _queueReplaced(PlayQueue previous) {
    if (previous.order.isEmpty || _replacedQueues.isClosed) return;
    _replacedQueues.add(previous);
  }

  /// The user (or an external controller) did something: saving goes on.
  void _userActed() => _saver?.unfreeze();

  /// Hands the engine the track that follows the current one; none while
  /// playback stops after the current track.
  Future<void> _queueNext() {
    final queue = state.queue;
    final next = _stopAfterCurrent ? null : queue.engineNextIndex;
    if (next != null) {
      final entry = queue.order[next];
      // Edits that keep the same next track would otherwise pile it up.
      if (_handedNext.lastOrNull != entry) _handedNext.add(entry);
    }
    return _backend.setNext(next == null ? null : queue.trackAt(next));
  }

  /// Loads the track at [index], playing or paused, from [start].
  Future<void> _play(
    int index, {
    bool play = true,
    Duration start = Duration.zero,
  }) async {
    final queue = state.queue.copyWith(index: index);
    if (index < 0 || index >= queue.order.length) return;
    _upNext.remove(queue.order[index]);
    _turn++;
    _intendLoad(play);
    _openedSinceBuild = true;
    _handedNext.clear();
    _dropRepeatTimes();
    // A track loaded without playing is paused, not stopped.
    state = state.copyWith(
      queue: queue,
      playing: play,
      stopped: false,
      position: start,
      duration: Duration.zero,
      playthrough: state.playthrough + 1,
    );
    // Read after the update: a listener may have turned the stop after the
    // current track on or off (and handed the next track for it already).
    final next = _stopAfterCurrent ? null : queue.engineNextIndex;
    if (next != null && _handedNext.lastOrNull != queue.order[next]) {
      _handedNext.add(queue.order[next]);
    }
    await _backend.open(
      queue.trackAt(index),
      next: next == null ? null : queue.trackAt(next),
      play: play,
      start: start,
    );
  }

  /// Plays the track at [index] in play order, as picked by the user.
  Future<void> jump(int index) {
    _userActed();
    _settleFade();
    _failuresInRow = 0;
    return _play(index);
  }

  /// How many "play next" tracks sit right after the current track. See
  /// `upNextRun`. Costs O(run) set lookups.
  int _upNextRun(PlayQueue queue) {
    var count = 0;
    final start = queue.index + 1;
    while (start + count < queue.order.length &&
        _upNext.contains(queue.order[start + count])) {
      count++;
    }
    return count;
  }

  /// Replaces the order with a fresh random one for the next pass (see
  /// [PlayQueuePasses.nextShuffledPass]). Everything in the old queue has
  /// played, so no "play next" mark is left to keep.
  void _startShuffledPass() {
    _upNext.clear();
    state = state.copyWith(
      queue: state.queue.nextShuffledPass(_random ?? Random()),
    );
  }

  /// Playback stopped for good: nothing is wanted playing and the engine's
  /// next-track bookkeeping is void. [ended] means the queue ran out (play
  /// restarts it); [resetPosition] false keeps the finished track to seek back
  /// into. [queue] swaps the queue in the same update. Leaves the engine alone,
  /// except for ending a counted repeat, which is the engine's loop.
  void _markStopped({
    required bool ended,
    bool resetPosition = true,
    PlayQueue? queue,
  }) {
    _intendStop(ended: ended);
    _handedNext.clear();
    _dropRepeatTimes();
    state = state.copyWith(
      queue: queue ?? state.queue,
      playing: false,
      stopped: true,
      position: resetPosition ? Duration.zero : state.position,
      duration: resetPosition ? Duration.zero : state.duration,
    );
  }

  /// Ends a counted repeat and hands the engine the base mode again, ahead of
  /// whatever it opens next. Nothing happens when no count is running.
  void _dropRepeatTimes() {
    if (state.repeatTimes == 0) return;
    state = state.copyWith(repeatTimes: 0);
    _followEngine(
      'stop the counted repeat',
      () => _backend.setRepeat(state.queue.repeat),
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

  /// The fader of this build, made on first use.
  PlayPauseFader get _fades {
    final existing = _fadesNow;
    if (existing != null) return existing;
    _fader?.dispose();
    final fader = PlayPauseFader(
      clock: ref.read(playbackFadeClockProvider),
      backend: _backend,
      state: () => state,
    );
    _fader = fader;
    _faderBuild = _seeked;
    ref.onDispose(fader.dispose);
    return fader;
  }

  /// The fader of this build if it was made; never makes one.
  PlayPauseFader? get _fadesNow =>
      identical(_faderBuild, _seeked) ? _fader : null;

  /// Ends a fade at once (see [PlayPauseFader.settle]) before a seek, a stop
  /// or a track change.
  void _settleFade() => _fadesNow?.settle();
}
