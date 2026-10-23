import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../m3u/m3u_read.dart';
import 'lyrics_text_decoder.dart';

/// Largest `.lrc` file read. Lyrics are a few KiB; anything larger is not a
/// lyrics file worth showing.
const lrcMaxBytes = 1024 * 1024;

/// Reads the `.lrc` file next to an audio file.
abstract interface class LrcSidecarReader {
  /// The decoded text of the lyrics file next to the audio file at
  /// [audioPath], or `null` when there is none.
  Future<String?> read(String audioPath);
}

/// The paths tried for [audioPath], in order: `<name>.lrc`, then
/// `<name>.LRC`, where `<name>` is the file name without its extension (a
/// name without one, or a dot file, is kept whole).
List<String> lrcCandidates(String audioPath) {
  final slash = audioPath.lastIndexOf('/');
  final dot = audioPath.lastIndexOf('.');
  final stem = dot > slash + 1 ? audioPath.substring(0, dot) : audioPath;
  return ['$stem.lrc', '$stem.LRC'];
}

/// [LrcSidecarReader] on the local file system. Only regular files are read
/// (a FIFO, device or folder of that name is never opened), at most
/// [lrcMaxBytes] of them; anything unreadable counts as absent.
class FileLrcSidecarReader implements LrcSidecarReader {
  const FileLrcSidecarReader();

  @override
  Future<String?> read(String audioPath) async {
    for (final candidate in lrcCandidates(audioPath)) {
      try {
        // The M3U reader already does the safe part: type check before
        // opening, one handle, a hard cap.
        final bytes = await readM3uBytes(candidate, maxBytes: lrcMaxBytes);
        return decodeLyricsBytes(bytes);
      } on M3uReadException catch (error) {
        // A missing file is the common case; try the next spelling. One that
        // exists but is unusable (too large, unreadable) ends the search.
        if (error.error != M3uReadError.notAFile) return null;
      }
    }
    return null;
  }
}

/// The app's `.lrc` reader; tests replace it.
final lrcSidecarReaderProvider = Provider<LrcSidecarReader>(
  (ref) => const FileLrcSidecarReader(),
);
