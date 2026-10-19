import 'package:logging/logging.dart';

import '../../src/rust/api/tags.dart' as native;
import '../../src/rust/frb_generated.dart';
import 'tag_reader.dart';

final _log = Logger('RustTagReader');

/// [TagReader] backed by the Rust `lofty` crate through flutter_rust_bridge.
///
/// The native library loads on the first read, not at app start, so a missing
/// or broken library fails the scan that needs it instead of blocking startup.
class RustTagReader implements TagReader {
  RustTagReader();

  Future<void>? _ready;

  @override
  Future<List<TrackTags>> readBatch(List<String> paths) async {
    await _ensureLoaded();
    return native.readTagsBatch(paths: paths);
  }

  /// Initialises the bridge once. A failed attempt is forgotten so a later
  /// call can retry instead of replaying the same error forever.
  Future<void> _ensureLoaded() {
    return _ready ??= RustLib.init().catchError((Object error, StackTrace st) {
      _log.severe('Cannot load the native tag reader', error, st);
      _ready = null;
      throw error;
    });
  }
}
