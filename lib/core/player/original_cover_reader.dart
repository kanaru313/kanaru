import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reads the full-size cover of an audio file.
abstract interface class OriginalCoverReader {
  /// The original image bytes of the cover of the file at [path], chosen as
  /// the library scan chooses; `null` when it has none.
  Future<Uint8List?> read(String path);
}

/// A reader that finds no cover.
class NoOriginalCoverReader implements OriginalCoverReader {
  const NoOriginalCoverReader();

  @override
  Future<Uint8List?> read(String path) async => null;
}

/// Defaults to no original covers; the app overrides it with the Rust reader
/// at startup.
final originalCoverReaderProvider = Provider<OriginalCoverReader>(
  (ref) => const NoOriginalCoverReader(),
);
