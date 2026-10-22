import '../indexer/cover_paths.dart' show isCoverKey;

/// Whether [art] names a thumbnail inside [directory]:
/// `<directory>/<a well-formed cover key>`.
bool isCoverPathIn(String directory, String? art) =>
    art != null &&
    art.startsWith('$directory/') &&
    isCoverKey(art.substring(directory.length + 1));
