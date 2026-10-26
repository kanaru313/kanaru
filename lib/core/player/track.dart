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
  });

  /// Builds a track from a local path, titled after the file name without
  /// its extension until real tags are read.
  factory Track.fromPath(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return Track(uri: path, title: dot > 0 ? name.substring(0, dot) : name);
  }

  /// `file://…` URI or plain local path, as handed to the player.
  final String uri;
  final String title;
  final String? artist;
  final String? artUri;
  final Duration? duration;

  /// Album and release year, shown on the queue row; null when unknown.
  final String? album;
  final int? year;

  @override
  bool operator ==(Object other) => other is Track && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;

  @override
  String toString() => 'Track($uri)';
}
