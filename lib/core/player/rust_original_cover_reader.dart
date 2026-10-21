import 'dart:typed_data';

import '../../src/rust/api/tags.dart' as native;
import '../native/rust_library.dart';
import 'original_cover_reader.dart';

/// [OriginalCoverReader] backed by the Rust tag reader. The native library
/// loads on the first read.
class RustOriginalCoverReader implements OriginalCoverReader {
  const RustOriginalCoverReader();

  @override
  Future<Uint8List?> read(String path) async {
    await ensureRustLibraryLoaded();
    return native.readOriginalCover(path: path);
  }
}
