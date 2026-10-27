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

  Future<void> setRepeat(RepeatMode repeat) async {
    if (state.queue.repeat == repeat) return;
    _userActed();
    state = state.copyWith(queue: state.queue.copyWith(repeat: repeat));
    await _backend.setRepeat(repeat);
    if (!state.queue.isEmpty) await _queueNext();
  }

  /// Off → all → all shuffled → one → off.
  Future<void> cycleRepeat() => setRepeat(switch (state.queue.repeat) {
    RepeatMode.off => RepeatMode.all,
    RepeatMode.all => RepeatMode.allShuffled,
    RepeatMode.allShuffled => RepeatMode.one,
    RepeatMode.one => RepeatMode.off,
  });
}
