part of 'player_service.dart';

/// Volume, shuffle and repeat. Shuffle and repeat are set to absolute values
/// (what an external controller sends); setting the current value again does
/// nothing, so it cannot reshuffle the queue.
mixin _PlayerSettingsCommands on Notifier<PlayerState> {
  AudioBackend get _backend;
  Random? get _random;
  int _upNextRun(PlayQueue queue);
  Future<void> _queueNext();
  void _userActed();
  bool get _ended;
  void _followEngine(String what, Future<void> Function() action);

  /// Sets the volume (0–100). Changing it while muted unmutes.
  Future<void> setVolume(double volume) async {
    _userActed();
    final value = volume.clamp(0, 100).toDouble();
    state = state.copyWith(volume: value, volumeBeforeMute: () => null);
    await _backend.setVolume(value);
  }

  Future<void> toggleMute() async {
    _userActed();
    final restore = state.volumeBeforeMute;
    if (restore != null) {
      await setVolume(restore);
    } else {
      final before = state.volume;
      state = state.copyWith(volume: 0, volumeBeforeMute: () => before);
      await _backend.setVolume(0);
    }
  }

  /// Turns shuffle on or off. The current track keeps playing; only the
  /// engine's next track changes. Tracks put right after it by "play next"
  /// keep their place and only the rest is shuffled.
  Future<void> setShuffle(bool on) async {
    final current = state.queue;
    if (current.shuffled == on) return;
    _userActed();
    state = state.copyWith(
      queue: on
          ? current.shuffle(_random, _upNextRun(current))
          : current.unshuffle(),
    );
    if (!state.queue.isEmpty) await _queueNext();
  }

  Future<void> toggleShuffle() => setShuffle(!state.queue.shuffled);

  /// Sets the base repeat mode. Also ends a counted repeat, even when the
  /// mode is the one already set.
  Future<void> setRepeat(RepeatMode repeat) async {
    if (state.queue.repeat == repeat && state.repeatTimes == 0) return;
    _userActed();
    state = state.copyWith(
      queue: state.queue.copyWith(repeat: repeat),
      repeatTimes: 0,
    );
    await _backend.setRepeat(repeat);
    if (!state.queue.isEmpty) await _queueNext();
  }

  /// Plays the current track [times] more times, then goes on in the repeat
  /// mode set now (1 to [maxRepeatTimes]; 0 ends the count). Under repeat one
  /// the base becomes off: looping forever would make the count meaningless.
  /// Does nothing without a queue or after it ran out.
  Future<void> setRepeatTimes(int times) async {
    if (state.queue.isEmpty || _ended) return;
    final count = times.clamp(0, maxRepeatTimes);
    if (count == state.repeatTimes) return;
    _userActed();
    if (count == 0) {
      _dropRepeatTimes();
      return;
    }
    final wasCounting = state.repeatTimes > 0;
    final queue = state.queue;
    state = state.copyWith(
      repeatTimes: count,
      queue: queue.repeat == RepeatMode.one
          ? queue.copyWith(repeat: RepeatMode.off)
          : queue,
    );
    // While counting the engine loops the track itself.
    if (!wasCounting) await _backend.setRepeat(RepeatMode.one);
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

  /// Off → all → all shuffled → one → off.
  Future<void> cycleRepeat() => setRepeat(switch (state.queue.repeat) {
    RepeatMode.off => RepeatMode.all,
    RepeatMode.all => RepeatMode.allShuffled,
    RepeatMode.allShuffled => RepeatMode.one,
    RepeatMode.one => RepeatMode.off,
  });
}
