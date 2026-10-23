import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/lrc_parser.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

Lyrics? _parse(String text) => parseLyricsText(text, LyricsSource.sidecar);

void main() {
  group('time tags', () {
    test('every fraction length and separator', () {
      final lyrics = _parse(
        '[00:01]a\n[00:02.5]b\n[00:03.25]c\n[00:04.125]d\n[00:05:50]e\n'
        '[100:00.00]f',
      )!;
      expect(lyrics.synced, isTrue);
      expect(lyrics.lines, [
        LyricLine(_ms(1000), 'a'),
        LyricLine(_ms(2500), 'b'),
        LyricLine(_ms(3250), 'c'),
        LyricLine(_ms(4125), 'd'),
        LyricLine(_ms(5500), 'e'),
        LyricLine(const Duration(minutes: 100), 'f'),
      ]);
    });

    test('several tags on one line repeat it, sorted by time', () {
      final lyrics = _parse('[00:10.00][00:01.00]Chorus\n[00:05.00]Verse')!;
      expect(lyrics.lines, [
        LyricLine(_ms(1000), 'Chorus'),
        LyricLine(_ms(5000), 'Verse'),
        LyricLine(_ms(10000), 'Chorus'),
      ]);
    });

    test('equal times keep the file order', () {
      final lyrics = _parse('[00:01.00]first\n[00:01.00]second')!;
      expect(lyrics.lines.map((l) => l.text), ['first', 'second']);
    });

    test('timed blank lines stay, untimed lines go', () {
      final lyrics = _parse('stray\n[00:01.00]\n[00:02.00]  sung  ')!;
      expect(lyrics.lines, [
        LyricLine(_ms(1000), ''),
        LyricLine(_ms(2000), 'sung'),
      ]);
    });

    test('word timings of enhanced LRC are removed', () {
      final lyrics = _parse('[00:01.00]<00:01.00>Hel<00:01.50>lo')!;
      expect(lyrics.lines.single.text, 'Hello');
    });

    test('CRLF and CR line ends', () {
      final lyrics = _parse('[00:01.00]a\r\n[00:02.00]b\r[00:03.00]c')!;
      expect(lyrics.lines.map((l) => l.text), ['a', 'b', 'c']);
    });
  });

  group('meta tags', () {
    test('are skipped', () {
      final lyrics = _parse(
        '[ar:Artist]\n[ti:Title]\n[al:Album]\n[by:me]\n[length: 03:20]\n'
        '[re:tool]\n[ve:1.0]\n[00:01.00]line',
      )!;
      expect(lyrics.lines, [LyricLine(_ms(1000), 'line')]);
    });

    test('a positive offset makes lines earlier, wherever it stands', () {
      final lyrics = _parse('[00:01.00]a\n[00:02.00]b\n[offset:+500]')!;
      expect(lyrics.lines.map((l) => l.time), [_ms(500), _ms(1500)]);
    });

    test('a negative offset makes lines later; below zero is zero', () {
      expect(
        _parse('[offset:-250]\n[00:01.00]a')!.lines.single.time,
        _ms(1250),
      );
      expect(
        _parse('[offset:2000]\n[00:01.00]a')!.lines.single.time,
        Duration.zero,
      );
    });

    test('a broken offset is ignored', () {
      expect(_parse('[offset:abc]\n[00:01.00]a')!.lines.single.time, _ms(1000));
    });
  });

  group('plain lyrics', () {
    test('lines kept as they are, blank edges trimmed', () {
      final lyrics = _parse('\n\n[ar:Someone]\nFirst line\n\n  Second  \n\n')!;
      expect(lyrics.synced, isFalse);
      expect(lyrics.lines.map((l) => l.text), ['First line', '', '  Second']);
      expect(lyrics.lineAt(const Duration(minutes: 1)), -1);
    });

    test('bracketed section names stay', () {
      final lyrics = _parse('[Chorus]\nLa la')!;
      expect(lyrics.lines.map((l) => l.text), ['[Chorus]', 'La la']);
    });

    test('nothing to show gives null', () {
      expect(_parse(''), isNull);
      expect(_parse('  \n \r\n'), isNull);
      expect(_parse('[ar:Only meta]\n[ti:Tags]'), isNull);
    });
  });

  test('keeps at most the line cap', () {
    final text = List.generate(
      maxLyricLines + 10,
      (i) => '[00:01.00]$i',
    ).join('\n');
    expect(_parse(text)!.lines, hasLength(maxLyricLines));
  });

  test('the source is passed through', () {
    expect(
      parseLyricsText('words', LyricsSource.embedded)!.source,
      LyricsSource.embedded,
    );
  });

  group('lineAt', () {
    final lyrics = _parse(
      '[00:01.00]a\n[00:02.00]b\n[00:02.00]c\n[00:05.00]d',
    )!;

    test('before the first line is -1', () {
      expect(lyrics.lineAt(Duration.zero), -1);
      expect(lyrics.lineAt(_ms(999)), -1);
    });

    test('the last line started at or before the position', () {
      expect(lyrics.lineAt(_ms(1000)), 0);
      expect(lyrics.lineAt(_ms(1999)), 0);
      expect(lyrics.lineAt(_ms(2000)), 2);
      expect(lyrics.lineAt(_ms(4999)), 2);
      expect(lyrics.lineAt(const Duration(hours: 1)), 3);
    });
  });
}
