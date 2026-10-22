part of 'player_service.dart';

/// Feeds [AudioOutputSync] with what it follows: the playback settings, the
/// devices mpv lists, a device that failed to open and the queue.
mixin _PlayerAudioOutput on Notifier<PlayerState> {
  AudioBackend get _backend;

  /// Call once per build, after [_backend] is set.
  void _startAudioOutput() {
    // Read, not watched: the database is set once at startup, and a rebuild
    // would throw the queue away.
    final db = ref.read(libraryDatabaseProvider);
    final sync = AudioOutputSync(
      backend: _backend,
      lookup: db == null ? (_) async => const {} : albumKeyLookupFor(db),
      onFailedDeviceChanged: (name) =>
          ref.read(audioOutputFailedDeviceProvider.notifier).set(name),
    );
    ref.listen(
      settingsProvider.select((s) => s.playback),
      (_, prefs) => sync.setPrefs(prefs),
      fireImmediately: true,
    );
    // The UI clears the mark to retry the saved device; the sync's own clears
    // find `_failed` already null and do nothing.
    ref.listen(audioOutputFailedDeviceProvider, (previous, name) {
      if (previous != null && name == null) sync.retryDevice();
    });
    final subscriptions = [
      _backend.audioDevicesChanged.listen(sync.setDevices),
      _backend.audioDeviceFailed.listen(sync.markDeviceFailed),
    ];
    // Runs inside `state =`, before `_play` hands the track to the engine.
    // Position updates come several times a second and keep the same queue.
    listenSelf((previous, next) {
      if (identical(previous?.queue, next.queue)) return;
      sync.setQueue(next.queue);
    });
    ref.onDispose(() {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
      sync.dispose();
    });
  }
}
