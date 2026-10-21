import 'package:drift/drift.dart';

/// Folders the user added as music sources. Times are epoch milliseconds.
class LibraryRoots extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Canonical: symlinks resolved, no trailing slash.
  TextColumn get path => text().unique()();

  IntColumn get addedAt => integer()();

  /// Null until the first scan of this root finishes.
  IntColumn get lastScanAt => integer().nullable()();
}

/// One row per audio file found under a root. Artist and album are plain
/// text columns for now; no separate album or artist tables yet.
@TableIndex(name: 'tracks_root', columns: {#rootId})
// Serves the Songs list order (`ORDER BY title_sort, id`).
@TableIndex(name: 'tracks_title_sort', columns: {#titleSort, #id})
@TableIndex(
  name: 'tracks_album_key',
  columns: {#albumArtistKey, #albumTitleKey},
)
@TableIndex(name: 'tracks_keys_version', columns: {#keysVersion})
class Tracks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Deleting a root removes its tracks.
  IntColumn get rootId =>
      integer().references(LibraryRoots, #id, onDelete: KeyAction.cascade)();

  /// Absolute file path; the natural key used to match files on rescan.
  TextColumn get path => text().unique()();

  /// File modification time and size, compared on rescan to skip unchanged
  /// files.
  IntColumn get mtimeMs => integer()();
  IntColumn get sizeBytes => integer()();

  /// The tag title, else the file name.
  TextColumn get title => text()();

  /// Multi-value tags are joined with "; ".
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  TextColumn get albumArtist => text().nullable()();

  IntColumn get trackNo => integer().nullable()();
  IntColumn get trackTotal => integer().nullable()();
  IntColumn get discNo => integer().nullable()();
  IntColumn get discTotal => integer().nullable()();
  IntColumn get year => integer().nullable()();

  TextColumn get genre => text().nullable()();
  TextColumn get composer => text().nullable()();
  TextColumn get comment => text().nullable()();

  IntColumn get durationMs => integer().nullable()();
  IntColumn get bitrate => integer().nullable()();
  IntColumn get sampleRate => integer().nullable()();
  IntColumn get bitDepth => integer().nullable()();
  IntColumn get channels => integer().nullable()();

  /// When the file was first indexed; never changes on rescan.
  IntColumn get addedAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Why the tags could not be read; null when they were read fine.
  TextColumn get scanError => text().nullable()();

  /// Key of the cover thumbnail (a JPEG, longest side 512 px) in the cover
  /// cache folder: `<ab>/<hash>.jpg`, where `hash` is the blake3 of the
  /// original image bytes. Null when the track has no cover.
  TextColumn get coverKey => text().nullable()();

  /// The `coverScanVersion` (library_rows.dart) whose rules produced [coverKey]; 0 when the
  /// cover was never looked for. A lower value makes a rescan read the file
  /// again even when it is unchanged.
  IntColumn get coverScanVersion => integer().withDefault(const Constant(0))();

  // Keys derived from the text columns above by `trackKeysFor`
  // (track_keys.dart). Rows with `keysVersion < textKeysVersion` are keyed in
  // the background, so the columns may be empty until then.

  /// Artist part of the album key; null when the track has no album.
  TextColumn get albumArtistKey => text().nullable()();

  /// Title part of the album key; null when the track has no album.
  TextColumn get albumTitleKey => text().nullable()();

  /// The album's artist as shown: the album artist tag, else the first track
  /// artist.
  TextColumn get albumDisplayArtist => text().nullable()();

  /// Sort keys of the title, the artist tag and the album; the last two are
  /// null with their text.
  TextColumn get titleSort => text().withDefault(const Constant(''))();
  TextColumn get artistSort => text().nullable()();
  TextColumn get albumSort => text().nullable()();

  /// The `textKeysVersion` whose rules produced the keys above; 0 when they
  /// were never computed.
  IntColumn get keysVersion => integer().withDefault(const Constant(0))();
}

/// One row per artist credited on a track (the `artist` tag split into
/// names), so an artist page is an index lookup.
@TableIndex(name: 'track_artists_track', columns: {#trackId})
class TrackArtists extends Table {
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();

  /// `groupKey` of the name.
  TextColumn get artistKey => text()();

  /// The spelling seen first on this track.
  TextColumn get artistName => text()();

  @override
  Set<Column> get primaryKey => {artistKey, trackId};
}
