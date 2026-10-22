import 'm3u_relative_path.dart';

/// How exported lines name the files.
enum M3uPathStyle {
  /// `/home/me/Music/a.flac`: works wherever the file is opened from.
  absolute,

  /// `../Music/a.flac` from the folder of the M3U file: survives moving the
  /// music and the playlist together.
  relative,
}

/// One playlist entry to export. [title] is null for an entry that is not in
/// the library (no metadata, path only).
class M3uExportEntry {
  const M3uExportEntry({
    required this.path,
    this.title,
    this.artist,
    this.durationMs,
  });

  final String path;
  final String? title;
  final String? artist;
  final int? durationMs;
}

/// The text of an extended M3U file holding [entries] in order, with how
/// many entries were [written] and how many [skipped]: a path holding a line
/// break or NUL cannot be one M3U line, so it is left out.
///
/// [targetDir] is the canonical folder the file is written to; relative
/// lines are computed from it. A relative line that starts with `#` (read as
/// a comment) or has a `:` before its first `/` (read as a URL scheme by
/// some players) gets a `./` prefix.
({String text, int written, int skipped}) writeM3u(
  List<M3uExportEntry> entries, {
  required M3uPathStyle style,
  required String targetDir,
}) {
  final out = StringBuffer('#EXTM3U\n');
  var written = 0;
  var skipped = 0;
  for (final entry in entries) {
    final path = entry.path;
    if (path.contains('\n') || path.contains('\r') || path.contains('\u0000')) {
      skipped++;
      continue;
    }
    final title = entry.title;
    if (title != null) {
      final ms = entry.durationMs;
      final seconds = ms == null ? -1 : ms ~/ 1000;
      final artist = entry.artist;
      final label = artist == null || artist.isEmpty
          ? title
          : '$artist - $title';
      out.writeln('#EXTINF:$seconds,${_oneLine(label)}');
    }
    out.writeln(switch (style) {
      M3uPathStyle.absolute => path,
      M3uPathStyle.relative => _safeRelative(
        relativePath(from: targetDir, to: path),
      ),
    });
    written++;
  }
  return (text: out.toString(), written: written, skipped: skipped);
}

String _safeRelative(String line) {
  final colon = line.indexOf(':');
  final slash = line.indexOf('/');
  final looksLikeScheme = colon >= 0 && (slash < 0 || colon < slash);
  return line.startsWith('#') || looksLikeScheme ? './$line' : line;
}

/// [text] with C0 control characters (line breaks included) as spaces.
String _oneLine(String text) =>
    text.replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), ' ');
