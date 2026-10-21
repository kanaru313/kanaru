import 'package:logging/logging.dart';

import '../../src/rust/api/tags.dart' as native;
import '../../src/rust/frb_generated.dart';
import 'tag_reader.dart';

final _log = Logger('RustTagReader');

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

  Future<void>? _ready;

  @override
  Future<List<TrackTags>> readBatch(List<String> paths) async {
    await _ensureLoaded();
    return native.readTagsBatch(paths: paths);
  }

  @override
  Future<List<TrackCover>> readCovers(List<String> paths) async {
    await _ensureLoaded();
    // The empty string tells the native side to skip covers.
    return native.readCoversBatch(paths: paths, coverDir: coverDirectory ?? '');
  }

  /// Initialises the bridge once. A failed attempt is forgotten so a later
  /// call can retry instead of replaying the same error forever. Skips the
  /// init when something else already did it: the bridge throws if
  /// initialised twice.
  Future<void> _ensureLoaded() {
    if (RustLib.instance.initialized) return Future<void>.value();
    return _ready ??= RustLib.init().catchError((Object error, StackTrace st) {
      _log.severe('Cannot load the native tag reader', error, st);
      _ready = null;
      Error.throwWithStackTrace(error, st);
    });
  }
}
