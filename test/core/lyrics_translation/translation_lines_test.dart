import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics_translation/translation_lines.dart';

Lyrics _plain(List<String> texts) => Lyrics(
  lines: [for (final t in texts) LyricLine(Duration.zero, t)],
  synced: false,
  source: LyricsSource.embedded,
);

void main() {
  group('uniqueLineTexts', () {
    test('keeps a repeated chorus once, in first-appearance order', () {
      final lyrics = _plain(['verse', 'chorus', 'bridge', 'chorus', 'chorus']);
      expect(uniqueLineTexts(lyrics), ['verse', 'chorus', 'bridge']);
    });

    test('skips blank and whitespace-only lines', () {
      expect(uniqueLineTexts(_plain(['a', '', '   ', 'b'])), ['a', 'b']);
    });

    test('compares exact text', () {
      expect(uniqueLineTexts(_plain(['a', 'A', 'a '])), ['a', 'A', 'a ']);
    });
  });

  group('chunkLines', () {
    test('splits 120 lines by item cap into 50/50/20', () {
      final lines = [for (var i = 0; i < 120; i++) 'l$i'];
      final chunks = chunkLines(lines, maxItems: 50, maxChars: 100000);
      expect(chunks.map((c) => c.length), [50, 50, 20]);
      expect(chunks.expand((c) => c).toList(), lines);
    });

    test('splits earlier when the character cap is hit', () {
      final chunks = chunkLines(
        ['aaaa', 'bbbb', 'cccc', 'dd'],
        maxItems: 10,
        maxChars: 8,
      );
      expect(chunks, [
        ['aaaa', 'bbbb'],
        ['cccc', 'dd'],
      ]);
    });

    test('puts a single over-long line in its own chunk', () {
      final long = 'x' * 5000;
      final chunks = chunkLines(['a', long, 'b'], maxItems: 50, maxChars: 100);
      expect(chunks, [
        ['a'],
        [long],
        ['b'],
      ]);
    });

    test('returns no chunks for no lines', () {
      expect(chunkLines([], maxItems: 5, maxChars: 5), isEmpty);
    });
  });

  group('alignTranslations', () {
    const lines = [
      LyricLine(Duration.zero, 'hello'),
      LyricLine(Duration(seconds: 1), ''),
      LyricLine(Duration(seconds: 2), 'hello'),
      LyricLine(Duration(seconds: 3), 'missing'),
    ];

    test('gives repeated lines the same translation', () {
      final result = alignTranslations(lines, {'hello': 'xin chao'});
      expect(result, ['xin chao', null, 'xin chao', null]);
    });

    test('returns null for a translation equal to the source', () {
      final result = alignTranslations(
        [const LyricLine(Duration.zero, 'Hello ')],
        {'Hello ': ' hello'},
      );
      expect(result, [null]);
    });

    test('returns null for blank lines and empty translations', () {
      final result = alignTranslations(
        [
          const LyricLine(Duration.zero, ''),
          const LyricLine(Duration.zero, 'a'),
        ],
        {'': 'x', 'a': '  '},
      );
      expect(result, [null, null]);
    });
  });

  group('dominantLanguage', () {
    test('weights by characters, not by line count', () {
      final lang = dominantLanguage(
        ['a', 'b', 'c', 'a long japanese line'],
        ['en', 'en', 'en', 'ja'],
      );
      expect(lang, 'ja');
    });

    test('merges regional variants into the base code', () {
      expect(
        dominantLanguage(['abc', 'def', 'gh'], ['pt-BR', 'pt', 'en']),
        'pt',
      );
    });

    test('returns null when nothing was detected', () {
      expect(dominantLanguage(['a', 'b'], [null, null]), isNull);
      expect(dominantLanguage([], []), isNull);
    });
  });
}
