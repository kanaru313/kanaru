import 'lyrics.dart';

/// Most lines kept from one lyrics text; the rest is dropped. Matches the
/// cap on synchronized lines read from tags.
const maxLyricLines = 10000;

/// A time tag at the start of a line: `[mm:ss]`, `[mm:ss.f]` up to
/// `[mm:ss.fff]`, or `[mm:ss:ff]`.
final _timeTag = RegExp(r'^\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');

/// A tag that is not a time: `[ar:Artist]`, `[offset:+250]`, `[by:]`.
final _metaTag = RegExp(r'^\[([A-Za-z#]+):([^\]]*)\]\s*$');

/// Word timings of enhanced LRC (`<00:12.34>`), dropped from the text.
final _wordTag = RegExp(r'<\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?>');

/// Parses lyrics [text]: LRC when at least one line starts with a time tag,
/// plain lyrics otherwise. `null` when nothing is left to show.
///
/// LRC: a line may carry several time tags (one line per tag); meta tags
/// are skipped, and `[offset:ms]` (positive means earlier) applies to every
/// line wherever it stands; times below zero become zero. Lines without a
/// time tag are dropped, timed blank lines kept. Lines are sorted by time,
/// keeping the file's order for equal times.
///
/// Plain: meta tag lines are dropped and blank lines around the text
/// trimmed. Either way at most [maxLyricLines] lines are kept.
Lyrics? parseLyricsText(String text, LyricsSource source) {
  final rows = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final timed = <LyricLine>[];
  final plain = <String>[];
  var offsetMs = 0;
  for (final row in rows) {
    final line = row.trimLeft();
    final times = <Duration>[];
    var rest = line;
    for (
      var match = _timeTag.firstMatch(rest);
      match != null;
      match = _timeTag.firstMatch(rest)
    ) {
      times.add(_timeOf(match));
      rest = rest.substring(match.end);
    }
    if (times.isNotEmpty) {
      final words = rest.replaceAll(_wordTag, '').trim();
      for (final time in times) {
        if (timed.length < maxLyricLines) timed.add(LyricLine(time, words));
      }
      continue;
    }
    final meta = _metaTag.firstMatch(line);
    if (meta != null) {
      if (meta.group(1)!.toLowerCase() == 'offset') {
        offsetMs = int.tryParse(meta.group(2)!.trim()) ?? offsetMs;
      }
      continue;
    }
    if (plain.length < maxLyricLines) plain.add(row.trimRight());
  }

  if (timed.isNotEmpty) {
    final shift = Duration(milliseconds: offsetMs);
    final lines = [
      for (final line in timed)
        LyricLine(
          line.time - shift < Duration.zero ? Duration.zero : line.time - shift,
          line.text,
        ),
    ];
    _stableSortByTime(lines);
    return Lyrics(lines: lines, synced: true, source: source);
  }

  var start = 0;
  var end = plain.length;
  while (start < end && plain[start].trim().isEmpty) {
    start++;
  }
  while (end > start && plain[end - 1].trim().isEmpty) {
    end--;
  }
  if (start == end) return null;
  return Lyrics(
    lines: [
      for (final text in plain.sublist(start, end))
        LyricLine(Duration.zero, text),
    ],
    synced: false,
    source: source,
  );
}

Duration _timeOf(RegExpMatch match) {
  final minutes = int.parse(match.group(1)!);
  final seconds = int.parse(match.group(2)!);
  final fraction = match.group(3);
  // One digit is tenths, two hundredths, three milliseconds.
  final ms = fraction == null
      ? 0
      : int.parse(fraction) * const [100, 10, 1][fraction.length - 1];
  return Duration(minutes: minutes, seconds: seconds, milliseconds: ms);
}

/// `List.sort` is not stable; lines with the same time keep their order.
void _stableSortByTime(List<LyricLine> lines) {
  final indexed = [for (var i = 0; i < lines.length; i++) (i, lines[i])];
  indexed.sort((a, b) {
    final byTime = a.$2.time.compareTo(b.$2.time);
    return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
  });
  for (var i = 0; i < lines.length; i++) {
    lines[i] = indexed[i].$2;
  }
}
