import '../sources/remote_source_ref.dart';
import 'track.dart';

/// What the engine is given to play for [track].
///
/// A remote track with a [remoteUrl] gets the URL that returns (the stream
/// proxy's). A local track gets its own uri, and [remoteUrl] is not called.
/// When [remoteUrl] throws, [onFallback] is told once and the track's uri is
/// returned: the engine cannot open a `kanaru-source:` uri, so the track
/// fails and is skipped like a broken file.
Future<String> playUriFor(
  Track track,
  Future<String> Function(RemoteSourceRef)? remoteUrl,
  void Function(Object error) onFallback,
) async {
  final ref = track.remote;
  if (ref == null || remoteUrl == null) return track.uri;
  try {
    return await remoteUrl(ref);
  } on Object catch (error) {
    onFallback(error);
    return track.uri;
  }
}
