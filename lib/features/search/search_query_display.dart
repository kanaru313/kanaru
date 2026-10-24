import '../../core/search/search_query.dart';
import '../../core/search/search_query_parser.dart';
import '../../l10n/l10n.dart';

/// [raw] as prose instead of its `field:value` syntax, e.g. `artist:abc`
/// becomes `Nghệ sĩ: abc`, so a page title or message built around it does
/// not show the raw search syntax to the user.
String displaySearchQueryText(AppLocalizations l10n, String raw) {
  final parsed = parseSearchQuery(raw);
  final parts = <String>[
    for (final field in QueryField.values)
      if (parsed.termsFor(field).isNotEmpty)
        '${_fieldLabel(l10n, field)}: ${parsed.termsFor(field).join(' ')}',
    if (parsed.freeTerms.isNotEmpty) parsed.freeTerms.join(' '),
    if (parsed.years.isNotEmpty) parsed.years.map(yearFilterText).join(', '),
    if (parsed.formats.isNotEmpty) parsed.formats.join(', '),
    if (parsed.languages.isNotEmpty) parsed.languages.join(', '),
  ];
  return parts.isEmpty ? raw : parts.join(' · ');
}

String _fieldLabel(AppLocalizations l10n, QueryField field) => switch (field) {
  QueryField.artist => l10n.searchFieldArtist,
  QueryField.album => l10n.searchFieldAlbum,
  QueryField.genre => l10n.searchFieldGenre,
};

/// [filter] as typed, e.g. a single year, `min-max`, or `>=min`/`<=max`.
String yearFilterText(YearFilter filter) {
  final (min, max) = (filter.min, filter.max);
  if (min != null && max != null) return min == max ? '$min' : '$min-$max';
  if (min != null) return '>=$min';
  if (max != null) return '<=$max';
  return '';
}
