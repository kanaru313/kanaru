import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/search/search_fields.dart';
import 'package:kanaru/core/search/search_query.dart';
import 'package:kanaru/core/search/search_query_parser.dart';

YearFilter? _year(String q) {
  final years = parseSearchQuery(q).years;
  return years.isEmpty ? null : years.single;
}

void main() {
  group('free text', () {
    test('plain words are folded terms', () {
      final q = parseSearchQuery('  Sơn   Tùng ');
      expect(q.freeTerms, ['son', 'tung']);
      expect(q.hasFilters, isFalse);
    });

    test('empty and punctuation-only are empty', () {
      expect(parseSearchQuery('').isEmpty, isTrue);
      expect(parseSearchQuery('  ... ').isEmpty, isTrue);
    });

    test('quoted text without prefix is plain text', () {
      expect(parseSearchQuery('"abbey road"').freeTerms, ['abbey', 'road']);
    });
  });

  group('field prefixes', () {
    test('artist, album, genre', () {
      final q = parseSearchQuery(
        'artist:beatles album:"abbey road" genre:rock',
      );
      expect(q.termsFor(QueryField.artist), ['beatles']);
      expect(q.termsFor(QueryField.album), ['abbey', 'road']);
      expect(q.termsFor(QueryField.genre), ['rock']);
      expect(q.freeTerms, isEmpty);
      expect(q.isEmpty, isFalse);
    });

    test('prefix is case-insensitive', () {
      expect(parseSearchQuery('ARTIST:x').termsFor(QueryField.artist), ['x']);
    });

    test('value is folded', () {
      expect(parseSearchQuery('artist:Đen').termsFor(QueryField.artist), [
        'den',
      ]);
    });

    test('free text and filters mix', () {
      final q = parseSearchQuery('hey artist:beatles jude');
      expect(q.freeTerms, ['hey', 'jude']);
      expect(q.termsFor(QueryField.artist), ['beatles']);
    });

    test('empty value falls back to text', () {
      final q = parseSearchQuery('artist:');
      expect(q.termsFor(QueryField.artist), isEmpty);
      expect(q.freeTerms, ['artist']);
    });

    test('quoted empty value falls back to text', () {
      expect(parseSearchQuery('album:""').freeTerms, ['album']);
    });

    test('unknown prefix is text', () {
      final q = parseSearchQuery('foo:bar');
      expect(q.freeTerms, ['foo', 'bar']);
      expect(q.hasFilters, isFalse);
    });

    test('leading colon is text', () {
      expect(parseSearchQuery(':x').freeTerms, ['x']);
    });

    test('unclosed quote runs to the end', () {
      final q = parseSearchQuery('album:"abbey road');
      expect(q.termsFor(QueryField.album), ['abbey', 'road']);
    });

    test('repeated prefix appends', () {
      final q = parseSearchQuery('artist:a artist:b');
      expect(q.termsFor(QueryField.artist), ['a', 'b']);
    });
  });

  group('year', () {
    test('exact', () {
      expect(_year('year:2010'), const YearFilter(min: 2010, max: 2010));
    });

    test('greater and less', () {
      expect(_year('year:>2010'), const YearFilter(min: 2011));
      expect(_year('year:<2000'), const YearFilter(max: 1999));
      expect(_year('year:>=2010'), const YearFilter(min: 2010));
      expect(_year('year:<=2000'), const YearFilter(max: 2000));
    });

    test('range, reversed order swaps', () {
      expect(_year('year:2010-2015'), const YearFilter(min: 2010, max: 2015));
      expect(_year('year:2015-2010'), const YearFilter(min: 2010, max: 2015));
    });

    test('invalid values become text', () {
      for (final q in ['year:abc', 'year:0', 'year:99999', 'year:', 'year:>']) {
        final parsed = parseSearchQuery(q);
        expect(parsed.years, isEmpty, reason: q);
        expect(parsed.freeTerms, isNotEmpty, reason: q);
      }
      expect(parseSearchQuery('year:abc').freeTerms, ['year', 'abc']);
    });

    test('several years all apply', () {
      final q = parseSearchQuery('year:>2000 year:<2010');
      expect(q.years.length, 2);
      expect(q.years.every((y) => y.contains(2005)), isTrue);
      expect(q.years.every((y) => y.contains(2012)), isFalse);
    });

    test('YearFilter.contains is inclusive', () {
      const y = YearFilter(min: 2010, max: 2015);
      expect(y.contains(2010), isTrue);
      expect(y.contains(2015), isTrue);
      expect(y.contains(2009), isFalse);
      expect(y.contains(2016), isFalse);
    });

    test('filter only is not empty', () {
      final q = parseSearchQuery('year:2010');
      expect(q.isEmpty, isFalse);
      expect(q.hasFilters, isTrue);
      expect(q.freeTerms, isEmpty);
    });
  });

  group('language', () {
    test('prefix is case-insensitive and the value is trimmed', () {
      expect(parseSearchQuery('language:vi').languages, ['vi']);
      expect(parseSearchQuery('LANGUAGE:EN').languages, ['EN']);
      expect(parseSearchQuery('language:" Ti\u1ebfng Vi\u1ec7t "').languages, [
        'Ti\u1ebfng Vi\u1ec7t',
      ]);
    });

    test('several values are kept once each', () {
      expect(
        parseSearchQuery('language:vi language:en language:vi').languages,
        ['vi', 'en'],
      );
    });

    test('empty value is plain text', () {
      final q = parseSearchQuery('language:');
      expect(q.languages, isEmpty);
      expect(q.freeTerms, ['language']);
      final blank = parseSearchQuery('language:" "');
      expect(blank.languages, isEmpty);
    });

    test('counts as a filter and not as an empty query', () {
      final q = parseSearchQuery('language:vi');
      expect(q.isEmpty, isFalse);
      expect(q.hasFilters, isTrue);
      expect(q.freeTerms, isEmpty);
    });

    test('request key tells languages apart, ignoring spelling of one', () {
      String key(String raw) => SearchRequest(
        query: parseSearchQuery(raw),
        fields: defaultSearchFields,
      ).key;
      expect(key('language:vi'), isNot(key('language:en')));
      expect(key('language:vi'), key('language:vie'));
      expect(key('language:vi language:en'), key('language:eng language:vi'));
      expect(key('x'), isNot(key('x language:vi')));
    });
  });

  group('format', () {
    test('lower-cases and accepts audio extensions', () {
      expect(parseSearchQuery('format:FLAC').formats, {'flac'});
    });

    test('several formats are a set', () {
      expect(parseSearchQuery('format:flac format:mp3').formats, {
        'flac',
        'mp3',
      });
    });

    test('non-audio extension is text', () {
      final q = parseSearchQuery('format:exe');
      expect(q.formats, isEmpty);
      expect(q.freeTerms, ['format', 'exe']);
    });

    test('filter only is not empty', () {
      expect(parseSearchQuery('format:flac').isEmpty, isFalse);
    });
  });

  group('term cap', () {
    test('free, field and quoted words total at most eight in order', () {
      final q = parseSearchQuery('a b c d artist:e f album:"g h i j"');
      expect(q.freeTerms, ['a', 'b', 'c', 'd', 'f']);
      expect(q.termsFor(QueryField.artist), ['e']);
      expect(q.termsFor(QueryField.album), ['g', 'h']);
    });

    test('filters without words are not capped', () {
      final q = parseSearchQuery('a b c d e f g h year:2000 format:flac');
      expect(q.freeTerms.length, 8);
      expect(q.years.length, 1);
      expect(q.formats, {'flac'});
    });
  });

  group('SearchRequest.key', () {
    final all = SearchFieldPreset.all.fields;

    SearchRequest req(String q, [Set<SearchField>? fields]) =>
        SearchRequest(query: parseSearchQuery(q), fields: fields ?? all);

    test('same meaning gives same key and equality', () {
      final a = req('Sơn  Tùng format:flac format:mp3');
      final b = req('son tung format:MP3 format:flac');
      expect(a.key, b.key);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('field set order does not matter, content does', () {
      final a = req('x', {SearchField.title, SearchField.artist});
      final b = req('x', {SearchField.artist, SearchField.title});
      expect(a, b);
      expect(a, isNot(req('x', {SearchField.title})));
    });

    test('different filters differ', () {
      expect(req('x year:2010'), isNot(req('x year:2011')));
      expect(req('artist:x'), isNot(req('album:x')));
      expect(req('x'), isNot(req('artist:x')));
    });

    test('year order does not change the key', () {
      expect(req('year:>2000 year:<2010'), req('year:<2010 year:>2000'));
    });

    test('repeated year filters do not change the key', () {
      expect(req('year:2010 year:2010').key, req('year:2010').key);
    });

    test('artist and album keys do not collide', () {
      expect(req('artist:x').key, isNot(req('album:x').key));
    });

    test('parsed query is immutable', () {
      final q = parseSearchQuery('x artist:y year:2010 format:mp3');
      expect(() => q.freeTerms.add('z'), throwsUnsupportedError);
      expect(() => q.years.add(const YearFilter()), throwsUnsupportedError);
      expect(() => q.formats.add('flac'), throwsUnsupportedError);
      expect(
        () => q.fieldTerms[QueryField.album] = ['z'],
        throwsUnsupportedError,
      );
      expect(
        () => q.fieldTerms[QueryField.artist]!.add('z'),
        throwsUnsupportedError,
      );
    });

    test('fields are an unmodifiable copy', () {
      final source = {SearchField.title};
      final r = req('x', source);
      source.add(SearchField.genre);
      expect(r.fields, {SearchField.title});
      expect(() => r.fields.add(SearchField.album), throwsUnsupportedError);
    });
  });
}
