import '../../src/rust/api/lyrics.dart' as native;
import '../native/rust_library.dart';
import 'embedded_lyrics_reader.dart';
import 'lyrics.dart';

/// [EmbeddedLyricsReader] backed by the Rust tag reader. The read runs on a
/// native thread; the UI isolate only awaits it.
class RustEmbeddedLyricsReader implements EmbeddedLyricsReader {
  const RustEmbeddedLyricsReader();

  @override
  Future<EmbeddedLyricsData?> read(String path) async {
    await ensureRustLibraryLoaded();
    final lyrics = await native.readEmbeddedLyrics(path: path);
    if (lyrics == null) return null;
    return (
      text: lyrics.text,
      synced: [
        for (final line in lyrics.synced)
          LyricLine(Duration(milliseconds: line.timeMs), line.text),
      ],
    );
  }
}
