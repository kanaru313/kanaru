/// Builds the SQL of a song search from a [SearchRequest]. Pure: no database,
/// so the text and the variables can be tested alone.
library;

import 'package:drift/drift.dart' show Variable;

import '../search/search_fields.dart';
import '../search/search_query.dart';
import 'library_browse_queries.dart' show songColumns;
import 'search_terms.dart';

/// Score given to a song that matched only by file name or comment: far
/// worse than any bm25 score (those are small negative numbers), so songs
/// that matched a tag always come first.
const extraMatchScore = 1e9;

/// Ranking: the full-text score, then title.
const _scoreOrder = 'score, title_sort, id';

/// For a one-character single-term query about half the library matches and
/// the score is noise, so the order is by title alone.
const _titleOrder = 'title_sort, id';

/// The same, when file name matches are mixed in: tag matches still lead.
const _titleOrderTagFirst = '(score >= $extraMatchScore), title_sort, id';

/// bm25 weights, in the column order of `track_search` (title, artist, album,
/// album artist, genre), the title far ahead.
const _bm25 = 'bm25(track_search, 20.0, 2.0, 1.5, 1.0, 0.5)';

/// The final SQL and its variables: `?1` the full-text query, `?2` the JSON
/// array of extra ids, `?3` the limit, then (only when extra ids are given and
/// there are field terms) `?4` the field-only full-text query, then the
/// filter values. Selected columns are [songColumns] plus
/// `total`, the count of all matches before the limit.
class SongSearchSql {
  const SongSearchSql(this.sql, this.variables);

  final String sql;
  final List<Variable<Object>> variables;
}

/// The FTS5 `MATCH` string for the free text of [request] in its selected
/// tag columns; null when there is nothing to match there. With all five
/// columns no column filter is written, which is the plain prefix query.
String? freeTextMatch(SearchRequest request) {
  final free = request.query.freeTerms;
  final columns = ftsColumns(request.fields);
  if (free.isEmpty || columns.isEmpty) return null;
  final terms = ftsPrefixQuery(free);
  return columns.length == ftsColumns(SearchField.values.toSet()).length
      ? terms
      : '{${columns.join(' ')}} : ($terms)';
}

/// The FTS5 `MATCH` string for `artist:`, `album:` and `genre:` terms, each
/// kept to its own column whatever the chosen fields; null when there are
/// none.
String? fieldTermsMatch(ParsedSearchQuery query) {
  const columns = {
    QueryField.artist: 'artist_search',
    QueryField.album: 'album_search',
    QueryField.genre: 'genre_search',
  };
  final parts = [
    for (final entry in columns.entries)
      if (query.termsFor(entry.key).isNotEmpty)
        '${entry.value} : (${ftsPrefixQuery(query.termsFor(entry.key))})',
  ];
  return parts.isEmpty ? null : parts.join(' AND ');
}

/// The SQL for [request], or null when nothing can match: no word and no
/// filter, or free text asked only in file name and comment with no
/// [hasExtra] ids found for it.
///
/// [hasExtra]: ids that matched by file name or comment are bound to `?2`
/// (see [SongSearchSql]); they rank after tag matches and still have to
/// satisfy the `artist:`, `album:` and `genre:` terms and the filters.
SongSearchSql? buildSongSearchSql(
  SearchRequest request, {
  required bool hasExtra,
  required int limit,
  String extraIdsJson = '[]',
}) {
  final query = request.query;
  if (query.isEmpty) return null;
  final free = freeTextMatch(request);
  final fields = fieldTermsMatch(query);
  // Free text with no tag column to look in can only match through the
  // extra ids.
  final extraOnly = query.freeTerms.isNotEmpty && free == null;
  // Extra ids come from the free words, so without free words they are
  // ignored: a filter-only search must still scan every track.
  hasExtra = hasExtra && query.freeTerms.isNotEmpty;
  if (extraOnly && !hasExtra) return null;

  // File name and comment hits only narrow by the field terms, so when the
  // free words can match only there, the field terms alone select nothing.
  final matches = extraOnly ? [?fields] : [?free, ?fields];
  final fts = matches.length > 1
      ? matches.map((m) => '($m)').join(' AND ')
      : matches.firstOrNull;

  final tagHits = (fts == null || extraOnly)
      ? null
      : 'SELECT rowid AS hit, $_bm25 AS score FROM track_search '
            'WHERE track_search MATCH ?1';
  final extraHits = !hasExtra
      ? null
      : 'SELECT DISTINCT value AS hit, $extraMatchScore AS score FROM json_each(?2)'
            "${fields == null ? '' : ' WHERE value IN (SELECT rowid FROM track_search WHERE track_search MATCH ?4)'}";
  final String hits;
  if (tagHits != null && extraHits != null) {
    hits =
        'SELECT hit, min(score) AS score FROM ($tagHits UNION ALL $extraHits) '
        'GROUP BY hit';
  } else {
    hits = tagHits ?? extraHits ?? 'SELECT id AS hit, 0 AS score FROM tracks';
  }

  // `?4` exists only when the extra ids are checked against field terms.
  final fieldsForExtra = hasExtra ? fields : null;
  final filter = _filters(query, fieldsForExtra == null ? 4 : 5);
  final where = filter.clauses.isEmpty
      ? ''
      : ' WHERE ${filter.clauses.join(' AND ')}';
  final countFrom = filter.clauses.isEmpty
      ? '($hits)'
      : '($hits) JOIN tracks ON id = hit$where';

  final allTerms = [
    ...query.freeTerms,
    for (final f in QueryField.values) ...query.termsFor(f),
  ];
  final oneChar = allTerms.length == 1 && allTerms.single.runes.length == 1;
  final order = !oneChar
      ? _scoreOrder
      : hasExtra
      ? _titleOrderTagFirst
      : _titleOrder;

  final sql =
      'SELECT $songColumns, (SELECT count(*) FROM $countFrom) AS total '
      'FROM tracks JOIN ($hits) ON id = hit$where '
      'ORDER BY $order LIMIT ?3';
  return SongSearchSql(sql, [
    Variable.withString(fts ?? ''),
    Variable.withString(extraIdsJson),
    Variable.withInt(limit < 1 ? 1 : limit),
    ?(fieldsForExtra == null ? null : Variable.withString(fieldsForExtra)),
    ...filter.variables,
  ]);
}

/// `WHERE` clauses on `tracks` for the year and format filters, numbering
/// their variables from [first].
({List<String> clauses, List<Variable<Object>> variables}) _filters(
  ParsedSearchQuery query,
  int first,
) {
  final clauses = <String>[];
  final variables = <Variable<Object>>[];
  int next() => first + variables.length;
  for (final y in query.years) {
    final parts = <String>[];
    if (y.min != null) {
      parts.add('year >= ?${next()}');
      variables.add(Variable.withInt(y.min!));
    }
    if (y.max != null) {
      parts.add('year <= ?${next()}');
      variables.add(Variable.withInt(y.max!));
    }
    if (parts.isNotEmpty) clauses.add('(${parts.join(' AND ')})');
  }
  if (query.formats.isNotEmpty) {
    final parts = <String>[];
    for (final format in query.formats.toList()..sort()) {
      parts.add("lower(path) LIKE ?${next()}");
      variables.add(Variable.withString('%.$format'));
    }
    clauses.add('(${parts.join(' OR ')})');
  }
  return (clauses: clauses, variables: variables);
}
