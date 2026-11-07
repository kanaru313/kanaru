import '../sources/remote_source_ref.dart';

/// One playable item in the queue. Two tracks are the same when they point at
/// the same [uri], whatever metadata they carry.
class Track {
  const Track({
    required this.uri,
    required this.title,
    this.artist,
    this.artUri,
    this.duration,
    this.album,
    this.year,
    this.remote,
  });

  /// Builds a track from a local path, titled after the file name without
  /// its extension until real tags are read.
  factory Track.fromPath(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return Track(uri: path, title: dot > 0 ? name.substring(0, dot) : name);
  }

  /// `file://…` URI or plain local path, as handed to the player. For a
  /// remote track ([remote] set) it is a `kanaru-source:` uri that only names
  /// the item: it is an identity and is never handed to mpv, the backend asks
  /// the stream proxy for the URL to play.
  final String uri;
  final String title;
  final String? artist;
  final String? artUri;
  final Duration? duration;

  /// Album and release year, shown on the queue row; null when unknown.
  final String? album;
  final int? year;

  /// Where a track found through a source plugin comes from; null for a
  /// local file. Its [uri] is then a `kanaru-source:` uri that only names the
  /// item: the engine plays the proxy URL made from this instead.
  final RemoteSourceRef? remote;

  @override
  bool operator ==(Object other) => other is Track && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;

  @override
  String toString() => 'Track($uri)';
}
