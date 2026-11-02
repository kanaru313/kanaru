/// What a song row of the library shows and acts on, whichever query read
/// it (`TrackListItem` for lists, `BrowseTrack` for the album, artist, genre
/// and language pages). Read-only; [id] and [path] identify the library
/// track. The player's `Track` is a queue snapshot and does not implement it.
abstract interface class SongRow {
  int get id;
  String get path;
  String get title;
  String? get artist;
  String? get album;
  int? get year;
  int? get durationMs;

  /// Cover thumbnail key in the cover cache; null when there is no cover.
  String? get coverKey;
}
