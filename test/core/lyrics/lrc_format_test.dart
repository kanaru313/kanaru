import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/lrc_format.dart';
import 'package:kanaru/core/lyrics/lrc_parser.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';

void main() {
  test('keeps milliseconds', () {
    expect(
      formatLrcLines(const [
        LyricLine(Duration(seconds: 1, milliseconds: 5), 'a'),
        LyricLine(Duration(minutes: 2, seconds: 3, milliseconds: 450), 'b'),
      ]),
      '[00:01.005]a\n[02:03.450]b',
    );
  });

  test('a 999 minute line round-trips and longer ones stop at 999', () {
    const line = LyricLine(Duration(minutes: 999, seconds: 5), 'x');
    expect(
      parseLyricsText(
        formatLrcLines(const [line]),
        LyricsSource.sidecar,
      )!.lines,
      const [line],
    );
    expect(
      formatLrcLines(const [LyricLine(Duration(minutes: 1500), 'x')]),
      '[999:00.000]x',
    );
  });

  test('minutes are not capped at 99', () {
    expect(
      formatLrcLines(const [LyricLine(Duration(minutes: 123), 'long')]),
      '[123:00.000]long',
    );
  });

  test('line breaks inside a line become a space', () {
    expect(
      formatLrcLines(const [LyricLine(Duration.zero, 'a\r\nb\nc\rd')]),
      '[00:00.000]a b c d',
    );
  });

  test('a blank line keeps its stamp', () {
    expect(
      formatLrcLines(const [LyricLine(Duration(seconds: 4), '')]),
      '[00:04.000]',
    );
  });

  test('parsing the result gives the same lines', () {
    const lines = [
      LyricLine(Duration(milliseconds: 120), 'first'),
      LyricLine(Duration(seconds: 61, milliseconds: 7), 'second'),
      LyricLine(Duration(minutes: 100, seconds: 1), 'late'),
    ];

    final parsed = parseLyricsText(formatLrcLines(lines), LyricsSource.sidecar);

    expect(parsed!.synced, isTrue);
    expect(parsed.lines, lines);
  });
}
