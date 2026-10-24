import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/search/search_fields.dart';
import 'package:kanaru/core/search/search_query.dart';
import 'package:kanaru/core/search/search_query_parser.dart';
import 'package:kanaru/core/search/typo_correction.dart';

TypoDictionary _dict(Map<String, int> docs) =>
    TypoDictionary([for (final e in docs.entries) (term: e.key, doc: e.value)]);

SearchRequest _request(String raw) =>
    SearchRequest(query: parseSearchQuery(raw), fields: defaultSearchFields);

void main() {
  group('boundedTypoDistance', () {
    test('counts insert, delete, replace and neighbour swap as one', () {
      expect(boundedTypoDistance('song', 'song', 2), 0);
      expect(boundedTypoDistance('song', 'sonng', 2), 1);
      expect(boundedTypoDistance('song', 'sog', 2), 1);
      expect(boundedTypoDistance('song', 'sang', 2), 1);
      expect(boundedTypoDistance('sonn', 'snon', 2), 1);
    });

    test('gives null above the maximum', () {
      expect(boundedTypoDistance('song', 'sing a', 1), isNull);
      expect(boundedTypoDistance('abcd', 'wxyz', 2), isNull);
      expect(boundedTypoDistance('ab', 'abcdef', 2), isNull);
    });

    test('compares characters, not code units', () {
      expect(boundedTypoDistance('a😀b', 'a😁b', 1), 1);
    });
  });

  group('TypoDictionary.correct', () {
    final dict = _dict({
      'son': 9,
      'tung': 9,
      'beatles': 20,
      'metallica': 12,
      'songs': 3,
      'sone': 12,
    });

    test('fixes a swap, a missing and an extra letter', () {
      expect(dict.correct('tugn'), 'tung');
      expect(dict.correct('beatls'), 'beatles');
      expect(dict.correct('beaatles'), 'beatles');
    });

    test('allows two edits from eight characters', () {
      expect(dict.correct('metalica'), 'metallica');
      expect(dict.correct('metalicc'), 'metallica');
    });

    test('keeps one edit below eight characters', () {
      expect(dict.correct('beatxxs'), isNull); // two edits, 7 characters
      expect(dict.correct('mtalica'), isNull); // two edits, 7 characters
    });

    test('leaves short words alone', () {
      expect(dict.correct('son'), isNull);
      expect(dict.correct('sin'), isNull);
    });

    test('leaves a word that starts a known word', () {
      expect(dict.correct('beat'), isNull);
      expect(dict.correct('metal'), isNull);
      expect(dict.correct('beatles'), isNull);
    });

    test('leaves words of scripts without spaces', () {
      final d = _dict({'東京タワー': 4, '東京タワ': 2});
      expect(d.correct('東京タワァ'), isNull);
      expect(isCorrectableWord('안녕하세요'), isFalse);
      expect(isCorrectableWord('สวัสดี'), isFalse);
      expect(isCorrectableWord('tung'), isTrue);
    });

    test('picks the closest, then the most songs, then alphabetical', () {
      // "sonn" is one edit from son and sone, two from songs.
      expect(dict.correct('sonn'), 'sone'); // in more songs than "son"
      final tie = _dict({'band': 4, 'bank': 4, 'bond': 1});
      expect(tie.correct('banc'), 'band'); // equal docs: alphabetical
      final nearer = _dict({'abcd': 1, 'abxd': 50, 'abxy': 100});
      expect(nearer.correct('abce'), 'abcd');
    });

    test('a tie across lengths goes to the alphabetically first word', () {
      // "ccde" (4 characters) is visited before "abcde" (5), both one edit.
      final d = _dict({'ccde': 4, 'abcde': 4});
      expect(d.correct('bcde'), 'abcde');
      // More songs still beat the alphabet across lengths.
      final more = _dict({'ccde': 5, 'abcde': 4});
      expect(more.correct('bcde'), 'ccde');
    });

    test('only words within the allowed edits in length are compared', () {
      final d = _dict({'beatles': 1, 'beatlesxx': 1, 'metallica': 1});
      expect(d.correct('beatlss'), 'beatles');
      // 8 characters allow 2 edits: the 9-letter word is one insert away.
      expect(d.correct('metalica'), 'metallica');
      // 3 edits apart in length: never a candidate.
      expect(d.correct('beatxyz'), isNull);
    });

    test('compares characters outside the basic plane', () {
      final d = _dict({'a😀bc': 3});
      expect(d.correct('a😁bc'), 'a😀bc');
    });

    test('works on folded words with digits', () {
      final d = _dict({'2pac': 5, 'ed': 1});
      expect(d.correct('2pcc'), '2pac');
    });

    test('an empty dictionary corrects nothing', () {
      expect(_dict({}).correct('hello'), isNull);
    });

    test('handles a large dictionary', () {
      final big = _dict({
        for (var i = 0; i < 50000; i++) 'word${i.toRadixString(36)}': 1,
        'beatles': 7,
      });
      expect(big.length, 50001);
      expect(big.correct('beatls'), 'beatles');
    });
  });

  group('correctRequest', () {
    final dict = _dict({'son': 9, 'tung': 9, 'beatles': 20, 'adele': 3});

    test('replaces free and field words and keeps filters', () {
      final fix = correctRequest(
        _request('beatls artist:adle year:2010 format:flac'),
        dict,
      )!;
      expect(fix.request.query.freeTerms, ['beatles']);
      expect(fix.request.query.termsFor(QueryField.artist), ['adele']);
      expect(fix.request.query.years, isNotEmpty);
      expect(fix.request.query.formats, {'flac'});
      expect(fix.replacements, {'beatls': 'beatles', 'adle': 'adele'});
    });

    test('is null when no word changes', () {
      expect(correctRequest(_request('son tung'), dict), isNull);
      expect(correctRequest(_request('xyzxyz'), dict), isNull);
    });

    test('keeps a free word the caller knows, still fixes the others', () {
      final fix = correctRequest(
        _request('beatls adle'),
        dict,
        isKnownFreeWord: (w) => w == 'beatls',
      )!;
      expect(fix.request.query.freeTerms, ['beatls', 'adele']);
      expect(fix.replacements, {'adle': 'adele'});
      expect(
        correctRequest(_request('beatls'), dict, isKnownFreeWord: (_) => true),
        isNull,
      );
    });

    test('a known free word does not stop a field word being fixed', () {
      final fix = correctRequest(
        _request('beatls artist:beatls'),
        dict,
        isKnownFreeWord: (w) => w == 'beatls',
      )!;
      expect(fix.request.query.freeTerms, ['beatls']);
      expect(fix.request.query.termsFor(QueryField.artist), ['beatles']);
    });

    test('hasCorrectableWord needs a long word outside CJK', () {
      expect(hasCorrectableWord(_request('son tu')), isFalse);
      expect(hasCorrectableWord(_request('東京タワー')), isFalse);
      expect(hasCorrectableWord(_request('artist:beatls')), isTrue);
    });
  });

  group('correctedQueryText', () {
    test('swaps the fixed words and keeps the rest as typed', () {
      expect(correctedQueryText('Sonn  Tung', {'sonn': 'son'}), 'son  Tung');
      expect(
        correctedQueryText('artist:"Beatls" year:>2000', {'beatls': 'beatles'}),
        'artist:"beatles" year:>2000',
      );
    });

    test('matches accented words folded', () {
      expect(correctedQueryText('Sơnn', {'sonn': 'son'}), 'son');
    });
  });
}
