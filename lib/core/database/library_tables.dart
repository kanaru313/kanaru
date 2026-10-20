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
// Matches the list order (`ORDER BY title COLLATE NOCASE`); a plain index on
// `title` is BINARY and cannot serve it.
@TableIndex.sql('CREATE INDEX tracks_title ON tracks (title COLLATE NOCASE)')
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
}
