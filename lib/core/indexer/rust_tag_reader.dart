import 'dart:io';

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
/// With a [coverDirectory], the native side also finds each file's cover and
/// writes its thumbnail there; without one, covers are skipped.
class RustTagReader implements TagReader {
  RustTagReader({this.coverDirectory});

  final String? coverDirectory;

  Future<void>? _ready;
  Future<String>? _coverDir;

  @override
  Future<List<TrackTags>> readBatch(List<String> paths) async {
    await _ensureLoaded();
    final coverDir = await (_coverDir ??= _prepareCoverDirectory());
    return native.readTagsBatch(paths: paths, coverDir: coverDir);
  }

  /// Creates the cover folder once. If that fails covers are skipped (the
  /// empty string tells the native side so) and the tags are still read.
  Future<String> _prepareCoverDirectory() async {
    final dir = coverDirectory;
    if (dir == null) return '';
    try {
      await Directory(dir).create(recursive: true);
      return dir;
    } on FileSystemException catch (error) {
      _log.warning('Cover cache unavailable, covers skipped', error);
      return '';
    }
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
