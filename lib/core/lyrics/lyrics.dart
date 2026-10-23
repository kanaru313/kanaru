/// Where a track's lyrics came from.
enum LyricsSource {
  /// Stored in the audio file's tags.
  embedded,

  /// A `.lrc` file next to the audio file.
  sidecar,
}

/// One line of lyrics. [time] is when it starts; for plain (unsynchronized)
/// lyrics every line has [Duration.zero].
class LyricLine {
  const LyricLine(this.time, this.text);

  final Duration time;

  /// May be empty: a timed blank line marks an instrumental gap.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is LyricLine && other.time == time && other.text == text;

  @override
  int get hashCode => Object.hash(time, text);

  @override
  String toString() => 'LyricLine($time, $text)';
}

/// The lyrics of one track: never empty. When [synced], [lines] are sorted by
/// time and follow playback; otherwise they are shown as they are.
class Lyrics {
  const Lyrics({
    required this.lines,
    required this.synced,
    required this.source,
  });

  final List<LyricLine> lines;
  final bool synced;
  final LyricsSource source;

  /// Index of the line being sung at [position]: the last line starting at
  /// or before it, `-1` before the first line or when not [synced].
  int lineAt(Duration position) {
    if (!synced) return -1;
    var low = 0;
    var high = lines.length - 1;
    var found = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lines[mid].time <= position) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found;
  }

  @override
  String toString() =>
      'Lyrics(${lines.length} lines, synced: $synced, ${source.name})';
}
