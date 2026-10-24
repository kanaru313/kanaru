import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/search_song_sql.dart';
import 'package:kanaru/core/search/search_fields.dart';
import 'package:kanaru/core/search/search_query.dart';

SearchRequest _request({
  List<String> free = const [],
  Map<QueryField, List<String>> fields = const {},
  List<YearFilter> years = const [],
  Set<String> formats = const {},
  Set<SearchField>? searched,
}) => SearchRequest(
  query: ParsedSearchQuery(
    freeTerms: free,
    fieldTerms: fields,
    years: years,
    formats: formats,
  ),
  fields: searched ?? defaultSearchFields,
);

void main() {
  group('freeTextMatch', () {
    test('all five tag columns write the plain prefix query', () {
      expect(freeTextMatch(_request(free: ['son', 'tung'])), '"son"* "tung"*');
    });

    test('a column subset gets a column filter in table column order', () {
      expect(
        freeTextMatch(
          _request(
            free: ['lac', 'son'],
            searched: {SearchField.genre, SearchField.artist},
          ),
        ),
        '{artist_search genre_search} : ("lac"* "son"*)',
      );
    });

    test('title only', () {
      expect(
        freeTextMatch(
          _request(
            free: ['love'],
            searched: SearchFieldPreset.titleOnly.fields,
          ),
        ),
        '{title_sort} : ("love"*)',
      );
    });

    test('nothing without free words or without a tag column', () {
      expect(freeTextMatch(_request()), isNull);
      expect(
        freeTextMatch(_request(free: ['a'], searched: {SearchField.fileName})),
        isNull,
      );
    });
  });

  test('fieldTermsMatch keeps each field to its own column', () {
    final query = ParsedSearchQuery(
      fieldTerms: {
        QueryField.genre: ['jazz'],
        QueryField.artist: ['tay', 'lor'],
      },
    );
    expect(
      fieldTermsMatch(query),
      'artist_search : ("tay"* "lor"*) AND genre_search : ("jazz"*)',
    );
    expect(fieldTermsMatch(const ParsedSearchQuery()), isNull);
  });

  group('buildSongSearchSql', () {
    SongSearchSql? build(SearchRequest r, {bool extra = false}) =>
        buildSongSearchSql(r, hasExtra: extra, limit: 200);

    test('nothing to search gives no SQL', () {
      expect(build(_request()), isNull);
    });

    test('free text only in file name needs extra ids', () {
      final r = _request(free: ['a'], searched: {SearchField.fileName});
      expect(build(r), isNull);
      final sql = build(r, extra: true)!;
      expect(sql.sql, contains('json_each(?2)'));
      expect(sql.sql, isNot(contains('MATCH')));
    });

    test('plain words bind the old query and the limit', () {
      final sql = build(_request(free: ['son']))!;
      expect(sql.sql, contains('track_search MATCH ?1'));
      expect(sql.sql, isNot(contains('json_each')));
      expect(sql.sql, contains('ORDER BY score, title_sort, id LIMIT ?3'));
      expect(sql.variables.map((v) => v.value).toList(), ['"son"*', '[]', 200]);
    });

    test('filters only scan tracks in title order', () {
      final sql = build(
        _request(years: const [YearFilter(min: 2010, max: 2015)]),
      )!;
      expect(sql.sql, isNot(contains('MATCH')));
      expect(sql.sql, contains('year >= ?4 AND year <= ?5'));
      expect(sql.variables.map((v) => v.value).skip(3), [2010, 2015]);
    });

    test('formats are bound as LIKE patterns, sorted', () {
      final sql = build(_request(formats: {'mp3', 'flac'}))!;
      expect(sql.sql, contains('lower(path) LIKE ?4 OR lower(path) LIKE ?5'));
      expect(sql.variables.map((v) => v.value).skip(3), ['%.flac', '%.mp3']);
    });

    test('extra ids merge with tag hits and rank last', () {
      final sql = build(_request(free: ['son']), extra: true)!;
      expect(sql.sql, contains('UNION ALL'));
      expect(sql.sql, contains('min(score)'));
    });

    test('extra ids are checked against field terms', () {
      final sql = build(
        _request(
          free: ['son'],
          fields: {
            QueryField.artist: ['tung'],
          },
        ),
        extra: true,
      )!;
      expect(sql.sql, contains('MATCH ?4'));
      expect(sql.variables[3].value, 'artist_search : ("tung"*)');
    });

    test('extra ids are ignored without free words', () {
      final sql = build(
        _request(years: const [YearFilter(min: 2010)]),
        extra: true,
      )!;
      expect(sql.sql, isNot(contains('json_each')));
      expect(sql.sql, contains('year >= ?4'));
    });

    test('extra ids are deduplicated', () {
      final sql = build(
        _request(free: ['a'], searched: {SearchField.fileName}),
        extra: true,
      )!;
      expect(sql.sql, contains('SELECT DISTINCT value AS hit'));
    });

    test('file-only free text adds no tag hits from field terms', () {
      final sql = build(
        _request(
          free: ['live'],
          searched: {SearchField.comment},
          fields: {
            QueryField.artist: ['tay'],
          },
        ),
        extra: true,
      )!;
      expect(sql.sql, isNot(contains('MATCH ?1')));
      expect(sql.sql, contains('MATCH ?4'));
    });

    test('a one-character word orders by title', () {
      expect(
        build(_request(free: ['a']))!.sql,
        contains('ORDER BY title_sort, id'),
      );
      expect(
        build(_request(free: ['a']), extra: true)!.sql,
        contains('ORDER BY (score >= '),
      );
      expect(
        build(_request(free: ['ab']))!.sql,
        contains('ORDER BY score, title_sort, id'),
      );
    });
  });
}
