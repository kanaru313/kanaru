part of 'player_service.dart';

/// Volume, shuffle and repeat. Shuffle and repeat are set to absolute values
/// (what an external controller sends); setting the current value again does
/// nothing, so it cannot reshuffle the queue.
mixin _PlayerSettingsCommands on Notifier<PlayerState> {
  AudioBackend get _backend;
  Random? get _random;
  Future<void> _queueNext();

  /// Sets the volume (0–100). Changing it while muted unmutes.
  Future<void> setVolume(double volume) async {
    final value = volume.clamp(0, 100).toDouble();
    state = state.copyWith(volume: value, volumeBeforeMute: () => null);
    await _backend.setVolume(value);
  }

  Future<void> toggleMute() async {
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
  /// engine's next track changes.
  Future<void> setShuffle(bool on) async {
    final current = state.queue;
    if (current.shuffled == on) return;
    state = state.copyWith(
      queue: on ? current.shuffle(_random) : current.unshuffle(),
    );
    if (!state.queue.isEmpty) await _queueNext();
  }

  Future<void> toggleShuffle() => setShuffle(!state.queue.shuffled);

  Future<void> setRepeat(RepeatMode repeat) async {
    if (state.queue.repeat == repeat) return;
    state = state.copyWith(queue: state.queue.copyWith(repeat: repeat));
    await _backend.setRepeat(repeat);
    if (!state.queue.isEmpty) await _queueNext();
  }

  /// Off → all → one → off.
  Future<void> cycleRepeat() => setRepeat(switch (state.queue.repeat) {
    RepeatMode.off => RepeatMode.all,
    RepeatMode.all => RepeatMode.one,
    RepeatMode.one => RepeatMode.off,
  });
}
