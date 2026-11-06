import 'lyrics.dart';

/// The text of an `.lrc` file for synced [lines]: one `[mm:ss.fff]text` line
/// each, milliseconds kept and minutes not capped at 99. A line break inside
/// a line's text becomes a space, since it would otherwise split the line.
/// Minutes stop at 999, the most the parser reads. `parseLyricsText` reads
/// the result back to the same lines, except that it trims spaces around a
/// line's text and strips word tags.
String formatLrcLines(List<LyricLine> lines) =>
    [for (final line in lines) '${_stamp(line.time)}${_flatten(line.text)}']
        .join('\n');

String _stamp(Duration time) {
  final minutes = time.inMinutes > 999 ? 999 : time.inMinutes;
  final seconds = time.inSeconds % 60;
  final ms = time.inMilliseconds % 1000;
  return '[${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}.'
      '${ms.toString().padLeft(3, '0')}]';
}

String _flatten(String text) => text.replaceAll(RegExp(r'\r\n|\r|\n'), ' ');
