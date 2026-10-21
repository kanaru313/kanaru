/// Turns what the user typed into search terms, the one place that decides
/// them: the full-text query for songs and the name filter for albums and
/// artists both use these terms, so the three result groups agree.
library;

import 'text_keys.dart';

/// Most terms kept from a query; the rest are ignored.
const maxSearchTerms = 8;

/// What separates words: anything that is not a letter, a digit or a private
/// use character, the token characters of FTS5's `unicode61` tokenizer.
final _separators = RegExp(r'[^\p{L}\p{N}\p{Co}]+', unicode: true);

/// The words of [text], folded like the stored search columns (`sortKey`:
/// lower case, no accents, `đ` as `d`) and split on punctuation and spaces.
/// At most [maxSearchTerms]; empty when [text] has no letter or digit.
List<String> searchTerms(String text) {
  final terms = sortKey(text).split(_separators)..removeWhere((t) => t.isEmpty);
  return terms.length <= maxSearchTerms
      ? terms
      : terms.sublist(0, maxSearchTerms);
}

/// The FTS5 query for [terms]: each one quoted and a prefix, all required.
/// Terms hold only letters and digits, so none can close the quotes, and
/// words such as `and` or `near` are plain terms inside them.
String ftsPrefixQuery(List<String> terms) =>
    terms.map((t) => '"$t"*').join(' ');

/// Whether every term in [queryTerms] is a prefix of some term in
/// [nameTerms], in any order: what the FTS prefix query matches, for names
/// filtered in Dart.
bool termsMatch(List<String> nameTerms, List<String> queryTerms) {
  for (final query in queryTerms) {
    if (!nameTerms.any((name) => name.startsWith(query))) return false;
  }
  return true;
}
