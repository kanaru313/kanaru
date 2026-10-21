import 'library_database.dart';

extension TrackCoverLookup on LibraryDatabase {
  /// The cover key of the library track at [path], as a record, so that a
  /// track without a cover (`(coverKey: null)`) differs from no such track
  /// (`null`). One read on the unique `tracks.path` index.
  Future<({String? coverKey})?> coverKeyOf(String path) =>
      (selectOnly(tracks)
            ..addColumns([tracks.coverKey])
            ..where(tracks.path.equals(path)))
          .map((row) => (coverKey: row.read(tracks.coverKey)))
          .getSingleOrNull();
}
