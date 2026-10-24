/// Ranking of the songs of one page (an album, the queue…) for the filter box
/// of that page. Pure Dart, no database: the page already holds its songs.
library;

import '../database/search_terms.dart';

/// What the filter looks at in one song; [artist] and [album] may be missing.
typedef InPageEntry = ({String title, String? artist, String? album});

/// The folded words of a list of songs, built once so that a key press only
/// compares prefixes instead of folding every name again.
class InPageIndex {
  InPageIndex(Iterable<InPageEntry> entries) {
    for (final entry in entries) {
      final title = searchWords(entry.title);
      _titleWords.add(title);
      _allWords.add([
        ...title,
        if (entry.artist case final artist?) ...searchWords(artist),
        if (entry.album case final album?) ...searchWords(album),
      ]);
    }
  }

  final _titleWords = <List<String>>[];
  final _allWords = <List<String>>[];

  int get length => _titleWords.length;

  /// Positions (in the list the index was built from) of the songs that match
  /// every one of [terms] as the prefix of a word of the title, artist or
  /// album, best first:
  /// - the first word of the title starts with the first term and the title
  ///   has all the terms,
  /// - the title has all the terms,
  /// - the artist or the album has some of them.
  ///
  /// Songs of the same tier keep their order. No [terms] keeps every song.
  List<int> rank(List<String> terms) => [for (final t in tiers(terms)) ...t];

  /// The matches of [rank], kept apart by tier (best tier first, always
  /// three lists), so a caller can reorder the songs inside a tier. No
  /// [terms] puts every song in the first tier.
  List<List<int>> tiers(List<String> terms) {
    if (terms.isEmpty) {
      return [
        [for (var i = 0; i < length; i++) i],
        <int>[],
        <int>[],
      ];
    }
    final tiers = [<int>[], <int>[], <int>[]];
    for (var i = 0; i < length; i++) {
      final title = _titleWords[i];
      if (termsMatch(title, terms)) {
        final first = title.isNotEmpty && title.first.startsWith(terms.first);
        tiers[first ? 0 : 1].add(i);
      } else if (termsMatch(_allWords[i], terms)) {
        tiers[2].add(i);
      }
    }
    return tiers;
  }
}
