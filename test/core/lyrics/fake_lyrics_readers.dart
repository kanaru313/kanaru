import 'package:kanaru/core/lyrics/embedded_lyrics_reader.dart';
import 'package:kanaru/core/lyrics/lrc_sidecar_reader.dart';

/// Embedded lyrics by path; records every read. A path in [failing] throws.
class FakeEmbeddedLyricsReader implements EmbeddedLyricsReader {
  final byPath = <String, EmbeddedLyricsData>{};
  final failing = <String>{};
  final reads = <String>[];

  @override
  Future<EmbeddedLyricsData?> read(String path) async {
    reads.add(path);
    if (failing.contains(path)) throw StateError('broken tag');
    return byPath[path];
  }
}

/// `.lrc` text by audio path; records every read. A path in [failing]
/// throws.
class FakeLrcSidecarReader implements LrcSidecarReader {
  final byPath = <String, String>{};
  final failing = <String>{};
  final reads = <String>[];

  @override
  Future<String?> read(String audioPath) async {
    reads.add(audioPath);
    if (failing.contains(audioPath)) throw StateError('broken file');
    return byPath[audioPath];
  }
}
