import '../../core/player/track.dart';
import '../../core/sources/remote_source_ref.dart';
import '../../core/sources/source_models.dart';

/// The queue entry of one search result of the plugin [installId]. It has no
/// cover of its own: the screen shows a placeholder, never a downloaded image.
Track remoteTrackOf(String installId, SourceItem item) {
  final ref = RemoteSourceRef(
    installId: installId,
    itemId: item.id,
    artworkUrl: item.artworkUrl,
    webUrl: item.webUrl,
  );
  return Track(
    uri: remoteTrackUri(ref),
    title: item.title,
    artist: item.artist,
    duration: item.duration,
    remote: ref,
  );
}
