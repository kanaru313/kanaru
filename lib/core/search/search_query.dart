/// The parsed form of one search: what the user typed split into free words,
/// per-field words and filters, plus the fields to look at. Pure Dart.
library;

import '../database/language_tags.dart' show languageKey;
import 'search_fields.dart';

/// A song field a `field:value` prefix can narrow.
enum QueryField { artist, album, genre }

/// A year range, both ends inclusive; a null end is open.
class YearFilter {
  const YearFilter({this.min, this.max});

  final int? min;
  final int? max;

  /// Whether [year] is inside the range.
  bool contains(int year) =>
      (min == null || year >= min!) && (max == null || year <= max!);

  /// Stable text, used in request keys.
  String get key => '${min ?? ''}-${max ?? ''}';

  @override
  bool operator ==(Object other) =>
      other is YearFilter && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'YearFilter($key)';
}

/// What a raw query means. Every word is already folded like the stored
/// search columns.
class ParsedSearchQuery {
  const ParsedSearchQuery({
    this.freeTerms = const [],
    this.fieldTerms = const {},
    this.years = const [],
    this.formats = const {},
    this.languages = const [],
  });

  /// Words without a prefix: matched in the selected fields.
  final List<String> freeTerms;

  /// Words after `artist:`, `album:` or `genre:`.
  final Map<QueryField, List<String>> fieldTerms;

  /// Every `year:` filter; a song must satisfy all of them.
  final List<YearFilter> years;

  /// File extensions from `format:` (lower case); a song matches any.
  final Set<String> formats;

  /// Values from `language:`, trimmed as typed; a song matches any. Compared
  /// by language key, so `vi`, `vie` and `Vietnamese` are the same.
  final List<String> languages;

  /// Nothing to search for: no word and no filter.
  bool get isEmpty =>
      freeTerms.isEmpty &&
      fieldTerms.values.every((t) => t.isEmpty) &&
      years.isEmpty &&
      formats.isEmpty &&
      languages.isEmpty;

  /// Whether the query has a filter that is not free text.
  bool get hasFilters =>
      years.isNotEmpty ||
      formats.isNotEmpty ||
      languages.isNotEmpty ||
      fieldTerms.values.any((t) => t.isNotEmpty);

  /// Words after [field]'s prefix; empty when there are none.
  List<String> termsFor(QueryField field) => fieldTerms[field] ?? const [];
}

/// A parsed query and the fields to search: the key of the results provider.
class SearchRequest {
  SearchRequest({required this.query, required Set<SearchField> fields})
    : fields = Set.unmodifiable(fields);

  final ParsedSearchQuery query;
  final Set<SearchField> fields;

  /// Same meaning gives the same key: fields in enum order, years and formats
  /// sorted and deduplicated.
  late final String key = _buildKey();

  String _buildKey() {
    final fieldNames = [
      for (final f in SearchField.values)
        if (fields.contains(f)) f.name,
    ];
    final years = {for (final y in query.years) y.key}.toList()..sort();
    final formats = query.formats.toList()..sort();
    final languages = {for (final l in query.languages) languageKey(l)}.toList()
      ..sort();
    return [
      'f:${fieldNames.join(',')}',
      't:${query.freeTerms.join(' ')}',
      for (final f in QueryField.values)
        '${f.name.substring(0, 2)}:${query.termsFor(f).join(' ')}',
      'y:${years.join(',')}',
      'x:${formats.join(',')}',
      'l:${languages.join(',')}',
    ].join('|');
  }

  @override
  bool operator ==(Object other) => other is SearchRequest && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'SearchRequest($key)';
}
