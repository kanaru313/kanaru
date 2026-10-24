import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/search_terms.dart';
import 'package:kanaru/core/search/in_page_match.dart';

InPageIndex _index(List<InPageEntry> entries) => InPageIndex(entries);

InPageEntry _song(String title, {String? artist, String? album}) =>
    (title: title, artist: artist, album: album);

void main() {
  test('ranks the title start, then the title, then artist and album', () {
    final index = _index([
      _song('Hello', artist: 'Lovers'),
      _song('My Love', artist: 'Zed'),
      _song('Other', album: 'Love Songs'),
      _song('Love Story', artist: 'Ann'),
    ]);
    expect(index.rank(searchTerms('love')), [3, 1, 0, 2]);
  });

  test('tiers keeps the three tiers apart', () {
    final index = _index([
      _song('Hello', artist: 'Lovers'),
      _song('My Love'),
      _song('Love Story'),
    ]);
    expect(index.tiers(searchTerms('love')), [
      [2],
      [1],
      [0],
    ]);
  });

  test('equal tiers keep the original order', () {
    final index = _index([_song('b ab'), _song('a ab'), _song('c ab')]);
    expect(index.rank(searchTerms('ab')), [0, 1, 2]);
  });

  test('every term must match as the start of a word, in any order', () {
    final index = _index([
      _song('Love Story', artist: 'Taylor'),
      _song('Story', artist: 'Taylor'),
      _song('Lovely', artist: 'Billie'),
    ]);
    expect(index.rank(searchTerms('taylor love')), [0]);
    expect(index.rank(searchTerms('story lo')), [0]);
    expect(index.rank(searchTerms('ove')), isEmpty, reason: 'not a prefix');
  });

  test('folds accents and đ, so plain letters find marked ones', () {
    final index = _index([_song('Tình ca', artist: 'Đen'), _song('Other')]);
    expect(index.rank(searchTerms('tinh')), [0]);
    expect(index.rank(searchTerms('den')), [0]);
  });

  test('no terms keeps every song in order; a song may lack a title word', () {
    final index = _index([_song('a'), _song('...'), _song('c')]);
    expect(index.rank(const []), [0, 1, 2]);
    expect(index.rank(searchTerms('c')), [2]);
    expect(index.length, 3);
  });
}
