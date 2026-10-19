import '../../src/rust/api/tags.dart';

export '../../src/rust/api/tags.dart' show TrackTags;

/// Reads audio tags for the library indexer. Kept as an interface so the scan
/// pipeline can be tested with a fake instead of the native library.
abstract interface class TagReader {
  /// Reads the tags of every file in [paths]. The result has one entry per
  /// path, in the same order. A file that cannot be read yields an entry whose
  /// [TrackTags.error] is set; it never fails the whole call.
  ///
  /// Throws if the native reader itself cannot be loaded or run.
  Future<List<TrackTags>> readBatch(List<String> paths);
}
