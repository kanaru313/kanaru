import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/artist_names.dart';
import 'package:kanaru/core/database/genre_names.dart';
import 'package:kanaru/core/database/separator_rules.dart';
import 'package:kanaru/core/database/text_keys.dart';

SplitRules rules(
  List<String> separators, [
  List<String> keepWhole = const [],
]) => SplitRules(separators: separators, keepWhole: keepWhole);

void main() {
  group('symbols split anywhere, words need whitespace around', () {
    test('a symbol splits without spaces, any spacing', () {
      final r = rules(['|']);
      expect(splitArtists('A|B | C|  D', rules: r), ['A', 'B', 'C', 'D']);
    });

    test('a word splits in any case with whitespace on each side', () {
      final r = rules(['and']);
      expect(splitArtists('A AND B and C', rules: r), ['A', 'B', 'C']);
      expect(splitArtists('Sandy Andrews', rules: r), ['Sandy Andrews']);
      expect(splitArtists('Band', rules: r), ['Band']);
    });

    test('a word is not cut at the ends of the tag', () {
      final r = rules(['and']);
      expect(splitArtists('and B', rules: r), ['and B']);
      expect(splitArtists('A and', rules: r), ['A and']);
    });

    test('a word with a space inside matches any whitespace run', () {
      final r = rules(['and the']);
      expect(splitArtists('A  and\tthe B', rules: r), ['A', 'B']);
    });

    test('a token with a digit is a word', () {
      final r = rules(['x2']);
      expect(splitArtists('A x2 B', rules: r), ['A', 'B']);
      expect(splitArtists('Ax2B', rules: r), ['Ax2B']);
    });

    test('regular expression characters are literal', () {
      final r = rules(['.', '*', '(']);
      expect(splitArtists('a.b*c(d', rules: r), ['a', 'b', 'c', 'd']);
      expect(splitArtists('axb', rules: r), ['axb']);
    });

    test('longer separators win over ones they start with', () {
      final r = rules(['|', '||']);
      expect(splitArtists('A||B', rules: r), ['A', 'B']);
    });

    test('separators with another case or spacing are the same rules', () {
      expect(rules(['With', ' with ', 'WITH']), rules(['with']));
      expect(rules(['a', 'b']), rules(['b', 'a', '']));
      expect(rules(['a'], ['AC/DC']), isNot(rules(['a'])));
      expect(rules(['a'], ['AC/DC']), rules(['a'], [' ac/dc']));
    });
  });

  group('bracketed featuring', () {
    test('uses the word separators, in either bracket', () {
      final r = rules(['and']);
      expect(splitArtists('A (and B)', rules: r), ['A', 'B']);
      expect(splitArtists('A [AND B; C]', rules: r), ['A', 'B; C']);
    });

    test('works when the person removed the semicolon', () {
      final r = rules(['feat.', 'with']);
      expect(splitArtists('A (feat. B) with C', rules: r), ['A', 'B', 'C']);
    });

    test('is not used when no separator is a word', () {
      expect(splitArtists('A (feat. B)', rules: rules([';'])), ['A (feat. B)']);
    });

    test('a bracket without a separator word stays', () {
      expect(splitArtists('A (live)', rules: rules(['and'])), ['A (live)']);
    });
  });

  group('names to keep whole', () {
    test('keeps a name that holds a separator', () {
      final r = rules(['/'], ['AC/DC']);
      expect(splitArtists('AC/DC', rules: r), ['AC/DC']);
      expect(splitArtists('ac/dc/Ann', rules: r), ['ac/dc', 'Ann']);
      expect(splitArtists('Ann/AC/DC', rules: r), ['Ann', 'AC/DC']);
      expect(splitArtists('Shellac/DC Talk', rules: r), ['Shellac', 'DC Talk']);
    });

    test('whitespace inside the name only has to be the same run', () {
      final r = rules(['and'], ['Simon and  Garfunkel']);
      expect(splitArtists('simon AND garfunkel', rules: r), [
        'simon AND garfunkel',
      ]);
      expect(splitArtists('Simon and Garfunkel and Ann', rules: r), [
        'Simon and Garfunkel',
        'Ann',
      ]);
    });

    test('a name spanning several separators wins, longest first', () {
      final r = rules(['/'], ['a/b/c', 'a/b']);
      expect(splitArtists('a/b/c', rules: r), ['a/b/c']);
      expect(splitArtists('a/b/d', rules: r), ['a/b', 'd']);
      expect(splitArtists('x/a/b/c/y', rules: r), ['x', 'a/b/c', 'y']);
    });

    test('mixed separators inside a kept name', () {
      final r = rules(['/', ';'], ['a/b; c']);
      expect(splitArtists('a/b; c;d', rules: r), ['a/b; c', 'd']);
    });

    test('spaces around the separator make it another name', () {
      final r = rules(['/'], ['AC/DC']);
      expect(splitArtists('AC / DC', rules: r), ['AC', 'DC']);
    });

    test('a bracket boundary never joins names', () {
      final r = rules(['and'], ['a b']);
      expect(splitArtists('a (and b)', rules: r), ['a', 'b']);
    });

    test('a name without a separator in it changes nothing', () {
      final r = rules([';'], ['Beck']);
      expect(splitArtists('Beck; Ann', rules: r), ['Beck', 'Ann']);
    });

    test('keeps whole in genres too', () {
      final r = rules([';', '/'], ['Drum/Bass']);
      expect(splitGenres('Drum/Bass; Rock/Pop', rules: r), [
        'Drum/Bass',
        'Rock',
        'Pop',
      ]);
    });
  });

  group('edge rules', () {
    test('no separators keep the tag whole', () {
      expect(splitArtists('A; B / C', rules: rules([])), ['A; B / C']);
      expect(splitGenres('A; B', rules: rules([])), ['A; B']);
    });

    test('empty and blank entries are ignored', () {
      expect(splitArtists('A; B', rules: rules(['', '  ', ';'])), ['A', 'B']);
    });

    test('control characters in tags count as spaces for artists', () {
      final r = rules(['and']);
      expect(splitArtists('A\tand\tB', rules: r), ['A', 'B']);
    });

    test('a NUL in a tag is not a separator', () {
      final r = rules(['and']);
      expect(splitGenres('a\u0000b', rules: r), ['a\u0000b']);
      expect(splitArtists('a\u0000b', rules: r), ['a b']);
    });

    test('repeats by key are dropped, the first spelling stays', () {
      expect(splitArtists('Ann | ANN | Bob', rules: rules(['|'])), [
        'Ann',
        'Bob',
      ]);
    });

    test('rules with the same canonical form share one compiled matcher', () {
      expect(
        identical(rules(['and', 'AND']).splitter, rules(['and']).splitter),
        isTrue,
      );
    });

    test('many different rules keep working past the cache limit', () {
      for (var i = 0; i < 30; i++) {
        final mark = '~' * (i + 1);
        final r = rules([mark]);
        expect(splitArtists('a${mark}b', rules: r), ['a', 'b']);
      }
      expect(splitArtists('a#b', rules: rules(['#'])), ['a', 'b']);
    });
  });

  group('keys version', () {
    test('the default rules keep the plain text keys version', () {
      expect(keysVersionFor(defaultArtistRules), textKeysVersion);
      expect(
        keysVersionFor(
          rules(defaultArtistRules.separators.reversed.toList(), ['ac/dc']),
        ),
        textKeysVersion,
      );
    });

    test('other rules get a version above it that depends on them', () {
      final a = keysVersionFor(rules(['|']));
      final b = keysVersionFor(rules(['|', '#']));
      expect(a, greaterThan(textKeysVersion));
      expect(b, greaterThan(textKeysVersion));
      expect(a, isNot(b));
      expect(keysVersionFor(rules(['#', '|'])), b);
    });

    test('is stable across runs (recorded value)', () {
      expect(keysVersionFor(rules(['|'])), keysVersionFor(rules([' | '])));
      expect(keysVersionFor(rules(['|'])), lessThan(1 << 31));
    });
  });

  test(
    'a keep-whole name holding ";" stops ";" eating the spaces around it',
    () {
      // With such a name the matcher reads ";" like "/": no whitespace is
      // taken with it, so a word separator after it still splits.
      final plain = rules([';', 'with']);
      final holding = rules([';', 'with'], ['A;B']);
      expect(splitArtists('X ; with Y', rules: plain), ['X', 'with Y']);
      expect(splitArtists('X ; with Y', rules: holding), ['X', 'Y']);
      expect(splitArtists('A;B with Y', rules: holding), ['A;B', 'Y']);
    },
  );
  group('default artist separators', () {
    test('split on a comma and a double slash, not on a single slash', () {
      const r = defaultArtistRules;
      expect(splitArtists('A, B // C', rules: r), ['A', 'B', 'C']);
      expect(splitArtists('A/B', rules: r), ['A/B']);
      expect(splitArtists('AC/DC', rules: r), ['AC/DC']);
    });
  });
}
