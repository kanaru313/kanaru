part of 'player_service.dart';

/// Feeds [ReplayGainSync] and [OutputDeviceSync] with what it follows: the playback settings, the
/// devices mpv lists, a device that failed to open and the queue.
mixin _PlayerAudioOutput on Notifier<PlayerState> {
  AudioBackend get _backend;
  int get _turn;

  /// Call once per build, after [_backend] is set.
  void _startAudioOutput() {
    // Read, not watched: the database is set once at startup, and a rebuild
    // would throw the queue away.
    final db = ref.read(libraryDatabaseProvider);
    final replayGain = ReplayGainSync(
      backend: _backend,
      lookup: db == null ? (_) async => const {} : albumKeyLookupFor(db),
    );
    final output = OutputDeviceSync(
      backend: _backend,
      onFailedDeviceChanged: (name) =>
          ref.read(audioOutputFailedDeviceProvider.notifier).set(name),
    );
    // A rebuilt service keeps the failure provider; the new engine has not
    // failed yet. A provider cannot be written during a build, hence the
    // microtask.
    Future.microtask(() {
      if (ref.mounted) {
        ref.read(audioOutputFailedDeviceProvider.notifier).set(null);
      }
    });
    ref.listen(settingsProvider.select((s) => s.playback), (_, prefs) {
      replayGain.setPrefs(prefs);
      output.setPrefs(prefs);
    }, fireImmediately: true);
    // The UI clears the mark to retry the saved device; the sync's own clears
    // find it already null and do nothing.
    ref.listen(audioOutputFailedDeviceProvider, (previous, name) {
      if (previous != null && name == null) output.retryDevice();
    });
    // The list the engine has now, so a saved device is used without waiting
    // for the first change; the same list again from the stream is a no-op.
    output.setDevices(_backend.audioDevices);
    final subscriptions = [
      _backend.audioDevicesChanged.listen(output.setDevices),
      _backend.audioDeviceFailed.listen(output.markDeviceFailed),
    ];
    // Runs inside `state =`, before `_play` hands the track to the engine.
    // Position updates come several times a second and keep the same queue.
    listenSelf((previous, next) {
      if (identical(previous?.queue, next.queue)) return;
      replayGain.setQueue(next.queue, turn: _turn);
    });
    ref.onDispose(() {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
      replayGain.dispose();
      output.dispose();
    });
  }
}
