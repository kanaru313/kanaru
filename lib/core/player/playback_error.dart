import 'track.dart';

/// A track the engine could not play. The engine has already skipped it.
class PlaybackError {
  const PlaybackError(this.track, this.message);

  final Track track;

  /// Last error line the engine logged before giving up on the track, for
  /// diagnostics. The engine does not say which file a line is about.
  final String message;
}
