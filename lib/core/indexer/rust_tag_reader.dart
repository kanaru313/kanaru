import '../../src/rust/api/tags.dart' as native;
import '../native/rust_library.dart';
import 'tag_reader.dart';

/// [TagReader] backed by the Rust `lofty` crate through flutter_rust_bridge.
///
/// The native library loads on the first read, not at app start, so a missing
/// or broken library fails the scan that needs it instead of blocking startup.
///
/// With a [coverDirectory], [readCovers] finds each file's cover and writes
/// its thumbnail there (creating folders as needed; a write failure is
/// reported per file as [CoverStatus.failed]); without one, covers are
/// skipped.
class RustTagReader implements TagReader {
  RustTagReader({this.coverDirectory});

  final String? coverDirectory;

  @override
  Future<List<TrackTags>> readBatch(List<String> paths) async {
    await ensureRustLibraryLoaded();
    return native.readTagsBatch(paths: paths);
  }

  @override
  Future<List<TrackCover>> readCovers(List<String> paths) async {
    await ensureRustLibraryLoaded();
    // The empty string tells the native side to skip covers.
    return native.readCoversBatch(paths: paths, coverDir: coverDirectory ?? '');
  }
}
