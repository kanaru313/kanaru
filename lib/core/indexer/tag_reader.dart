import '../../src/rust/api/tags.dart';

export '../../src/rust/api/tags.dart' show CoverStatus, TrackCover, TrackTags;

/// Reads audio tags and covers for the library indexer. Kept as an interface
/// so the scan pipeline can be tested with a fake instead of the native
/// library.
abstract interface class TagReader {
  /// Reads the tags of every file in [paths], without pictures. The result
  /// has one entry per path, in the same order. A file that cannot be read
  /// yields an entry whose [TrackTags.error] is set; it never fails the whole
  /// call.
  ///
  /// Throws if the native reader itself cannot be loaded or run.
  Future<List<TrackTags>> readBatch(List<String> paths);

  /// Finds the cover of every file in [paths] and writes its thumbnail into
  /// the cover folder. One entry per path, in the same order; a file whose
  /// cover could not be read for a reason that may pass is
  /// [CoverStatus.failed], never [CoverStatus.none]. Without a cover folder
  /// every entry is [CoverStatus.skipped].
  ///
  /// Throws if the native reader itself cannot be loaded or run.
  Future<List<TrackCover>> readCovers(List<String> paths);
}
