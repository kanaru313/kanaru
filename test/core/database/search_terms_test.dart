import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/search_terms.dart';

void main() {
  test('folds accents, case and đ', () {
    expect(searchTerms('SƠN TÙNG'), ['son', 'tung']);
    expect(searchTerms('Đừng'), ['dung']);
  });

  test('splits on punctuation and spaces', () {
    expect(searchTerms('M-TP'), ['m', 'tp']);
    expect(searchTerms('AC/DC'), ['ac', 'dc']);
  });

  test('keeps digits and CJK runs', () {
    expect(searchTerms('1989'), ['1989']);
    expect(searchTerms('日本語の歌'), ['日本語の歌']);
  });

  test('empty or punctuation-only input has no terms', () {
    for (final text in ['', '   ', '!!!', '"*']) {
      expect(searchTerms(text), isEmpty, reason: text);
    }
  });

  test('keeps at most eight terms', () {
    expect(searchTerms('a b c d e f g h i j'), [
      'a',
      'b',
      'c',
      'd',
      'e',
      'f',
      'g',
      'h',
    ]);
    expect(maxSearchTerms, 8);
  });

  test('the FTS query quotes every term as a prefix', () {
    expect(ftsPrefixQuery(['son', 'tu']), '"son"* "tu"*');
  });

  test('operator words and syntax become plain terms', () {
    expect(searchTerms('NOT a OR b'), ['not', 'a', 'or', 'b']);
    expect(searchTerms('"x" AND y*'), ['x', 'and', 'y']);
    expect(searchTerms('a:b ^c (d)'), ['a', 'b', 'c', 'd']);
    expect(searchTerms('NEAR(a b)'), ['near', 'a', 'b']);
    expect(searchTerms('-x'), ['x']);
    expect(ftsPrefixQuery(searchTerms('NOT a OR b')), '"not"* "a"* "or"* "b"*');
  });

  test('a name matches when every term prefixes one of its words', () {
    final name = searchTerms('Sơn Tùng M-TP');
    expect(termsMatch(name, ['so', 'tu']), isTrue);
    expect(termsMatch(name, ['tp']), isTrue);
    expect(termsMatch(name, ['ung']), isFalse);
    expect(termsMatch(name, ['son', 'xx']), isFalse);
  });

  test('name matching ignores word order, case and accents', () {
    expect(
      termsMatch(searchTerms('Sơn Tùng'), searchTerms('TUNG son')),
      isTrue,
    );
  });
}
