import 'dart:async';
import 'dart:typed_data';

import 'package:kanaru/core/player/original_cover_reader.dart';

/// An [OriginalCoverReader] that answers from a map. A path with a
/// [Completer] stays pending until it completes; a path in [throwOn] throws;
/// any other path gives [bytes] or `null`.
class FakeOriginalCoverReader implements OriginalCoverReader {
  final bytes = <String, Uint8List?>{};
  final pending = <String, Completer<Uint8List?>>{};
  final throwOn = <String>{};

  /// Every path read, in order.
  final reads = <String>[];

  @override
  Future<Uint8List?> read(String path) {
    reads.add(path);
    if (throwOn.contains(path)) {
      return Future.error(StateError('cannot read $path'));
    }
    return pending[path]?.future ?? Future.value(bytes[path]);
  }
}
