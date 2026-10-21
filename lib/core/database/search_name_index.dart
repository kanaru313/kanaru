import 'library_browse_rows.dart';
import 'search_terms.dart';
import 'text_keys.dart' show sortKey;

class _Entry<T> {
  _Entry(this.order, this.item, String searchable, String primary, this.weight)
    : terms = searchTerms(searchable),
      lead = _firstTerm(primary),
      sort = sortKey(primary);

  /// Position in the source list: the last tie-break, so order is stable.
  final int order;
  final T item;
  final List<String> terms;

  /// First term of the primary name; null when it has none.
  final String? lead;
  final String sort;
  final int weight;
}

String? _firstTerm(String text) {
  final terms = searchTerms(text);
  return terms.isEmpty ? null : terms.first;
}

/// Names filtered in memory with the same terms as the song search. Built
/// once per loaded list, so a keystroke only runs [match].
class SearchNameIndex<T> {
  SearchNameIndex._(this._entries);

  final List<_Entry<T>> _entries;

  /// The items whose searchable text has every term of [terms] as the prefix
  /// of a word. Names that start with the first term come first, then the
  /// ones with more tracks, then by name. No terms match nothing.
  List<T> match(List<String> terms) {
    if (terms.isEmpty) return const [];
    final hits = [
      for (final e in _entries)
        if (termsMatch(e.terms, terms)) e,
    ];
    final first = terms.first;
    bool leads(_Entry<T> e) => e.lead?.startsWith(first) ?? false;
    hits.sort((a, b) {
      final lead = (leads(b) ? 1 : 0) - (leads(a) ? 1 : 0);
      if (lead != 0) return lead;
      final weight = b.weight.compareTo(a.weight);
      if (weight != 0) return weight;
      final name = a.sort.compareTo(b.sort);
      return name != 0 ? name : a.order.compareTo(b.order);
    });
    return [for (final e in hits) e.item];
  }
}

/// Albums searched by title and album artist.
SearchNameIndex<AlbumSummary> albumSearchIndex(List<AlbumSummary> albums) =>
    SearchNameIndex._([
      for (final (i, a) in albums.indexed)
        _Entry(i, a, '${a.title} ${a.artist ?? ''}', a.title, a.trackCount),
    ]);

/// Artists searched by their own name only, so a co-credited artist is never
/// listed for the name of the other.
SearchNameIndex<ArtistCredit> artistSearchIndex(List<ArtistCredit> credits) =>
    SearchNameIndex._([
      for (final (i, c) in credits.indexed)
        _Entry(i, c, c.name, c.name, c.trackCount),
    ]);
