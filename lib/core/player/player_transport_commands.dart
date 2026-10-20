part of 'player_service.dart';

/// Opening, play, pause, stop, seek and track changes. [play] and [pause] are
/// absolute, for external controllers that must not flip the state by
/// accident.
mixin _PlayerTransportCommands on Notifier<PlayerState> {
  AudioBackend get _backend;
  bool get _ended;
  set _ended(bool ended);
  set _lastTick(Duration position);
  StreamController<Duration> get _seeked;
  Random? get _random;
  set _failuresInRow(int count);
  set _wantsPlaying(bool wanted);
  Future<void> _play(int index);
  void _userActed();

  Future<void> playPause() async {
    if (state.queue.isEmpty) return;
    _userActed();
    if (_ended) return jump(0);
    final play = !state.playing;
    _wantsPlaying = play;
    state = state.copyWith(
      playing: play,
      stopped: play ? false : state.stopped,
    );
    await (play ? _backend.play() : _backend.pause());
  }

  Future<void> play() async {
    if (!state.playing) await playPause();
  }

  /// Also records the wish when the engine already reported a pause on its
  /// own, so a track that then fails moves on paused.
  Future<void> pause() async {
    if (state.playing) return playPause();
    _wantsPlaying = false;
  }

  /// Pauses and rewinds to the start but keeps the queue; [play] then plays
  /// the current track from the beginning. Rewinds the engine directly, not
  /// through [seek], which would announce a jump and clear `stopped`.
  Future<void> stop() async {
    if (state.queue.isEmpty) return;
    _userActed();
    _wantsPlaying = false;
    state = state.copyWith(
      playing: false,
      stopped: true,
      position: Duration.zero,
    );
    _lastTick = Duration.zero;
    await _backend.pause();
    await _backend.seek(Duration.zero);
  }

  Future<void> seek(Duration position) async {
    if (state.queue.isEmpty) return;
    _userActed();
    // Seeking back into a finished track resumes it rather than the queue.
    if (state.duration > Duration.zero) _ended = false;
    state = state.copyWith(position: position, stopped: false);
    _lastTick = position;
    await _backend.seek(position);
    _seeked.add(position);
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

  /// Replaces the queue with [tracks] and plays from [start]. Shuffle and
  /// repeat stay as they were. Opening nothing does nothing; a [start]
  /// outside [tracks] throws [ArgumentError] and leaves playback as it was.
  Future<void> openTracks(List<Track> tracks, {int start = 0}) async {
    if (tracks.isEmpty) return;
    RangeError.checkValidIndex(start, tracks, 'start');
    _userActed();
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
    _userActed();
    _failuresInRow = 0;
    return _play(index);
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
}
