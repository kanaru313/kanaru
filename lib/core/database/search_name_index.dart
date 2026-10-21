import 'library_browse_rows.dart';
import 'search_terms.dart';

class _Entry<T> {
  /// [primary] and [secondary] are folded once, here: the name is searchable
  /// by the words of both; the first word and the sort key come from
  /// [primary].
  _Entry._(
    this.order,
    this.item,
    List<String> primary,
    List<String> secondary,
    this.weight,
  ) : terms = [...primary, ...secondary],
      lead = primary.isEmpty ? null : primary.first,
      sort = primary.join(' ');

  factory _Entry(
    int order,
    T item,
    String primary,
    String secondary,
    int weight,
  ) => _Entry._(
    order,
    item,
    searchWords(primary),
    searchWords(secondary),
    weight,
  );

  /// Position in the source list: the last tie-break, so order is stable.
  final int order;
  final T item;
  final List<String> terms;

  /// First word of the primary name; null when it has none.
  final String? lead;

  /// The primary name's words: orders names alphabetically.
  final String sort;
  final int weight;
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
    final first = terms.first;
    // Whether the name leads is decided once per hit, not per comparison.
    final hits = [
      for (final e in _entries)
        if (termsMatch(e.terms, terms))
          (entry: e, leads: e.lead?.startsWith(first) ?? false),
    ];
    hits.sort((a, b) {
      if (a.leads != b.leads) return a.leads ? -1 : 1;
      final weight = b.entry.weight.compareTo(a.entry.weight);
      if (weight != 0) return weight;
      final name = a.entry.sort.compareTo(b.entry.sort);
      return name != 0 ? name : a.entry.order.compareTo(b.entry.order);
    });
    return [for (final h in hits) h.entry.item];
  }
}

/// Albums searched by title and album artist.
SearchNameIndex<AlbumSummary> albumSearchIndex(List<AlbumSummary> albums) =>
    SearchNameIndex._([
      for (final (i, a) in albums.indexed)
        _Entry(i, a, a.title, a.artist ?? '', a.trackCount),
    ]);

/// Artists searched by their own name only, so a co-credited artist is never
/// listed for the name of the other.
SearchNameIndex<ArtistCredit> artistSearchIndex(List<ArtistCredit> credits) =>
    SearchNameIndex._([
      for (final (i, c) in credits.indexed)
        _Entry(i, c, c.name, '', c.trackCount),
    ]);
