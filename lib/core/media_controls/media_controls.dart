/// Publishes playback state to the desktop (media keys, widgets, `playerctl`)
/// and takes commands back. One implementation per platform; the app only
/// holds on to it for the length of the session.
abstract interface class MediaControls {
  /// Stops publishing and gives back whatever the platform handed out.
  Future<void> dispose();
}

/// Does nothing. The default, so tests and platforms without an
/// implementation never open a system connection.
class NoopMediaControls implements MediaControls {
  @override
  Future<void> dispose() async {}
}
