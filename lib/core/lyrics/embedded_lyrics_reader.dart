import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lyrics.dart';
import 'rust_embedded_lyrics_reader.dart';

/// What an audio file's tags hold: a lyrics [text] (plain or LRC) and the
/// timed lines of an ID3v2 `SYLT` frame, either possibly absent.
typedef EmbeddedLyricsData = ({String? text, List<LyricLine> synced});

/// Reads the lyrics stored in an audio file.
abstract interface class EmbeddedLyricsReader {
  /// The lyrics in the tags of the file at [path]; `null` when it has none
  /// or cannot be read.
  Future<EmbeddedLyricsData?> read(String path);
}

/// The app's embedded lyrics reader, backed by the native tag reader (which
/// loads on the first read); tests replace it.
final embeddedLyricsReaderProvider = Provider<EmbeddedLyricsReader>(
  (ref) => const RustEmbeddedLyricsReader(),
);
