/// Forgives small typos: replaces a query word that no indexed word starts
/// with by the closest indexed word. Pure Dart, no database.
library;

import '../database/search_terms.dart';
import 'search_query.dart';

/// Fewer songs than this found for a query lets the search try a corrected
/// one.
const typoRetryBelow = 5;

/// Shortest word (in characters) that is ever corrected: shorter words are
/// too close to too many others.
const typoMinLength = 4;

/// Scripts written without spaces, whose indexed word is a whole phrase, so
/// an edit distance means nothing there.
final _unspaced = RegExp(
  r'[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}'
  r'\p{Script=Hangul}\p{Script=Thai}]',
  unicode: true,
);

/// The most edits tolerated in a word of [length] characters.
int maxTypoDistance(int length) => length >= 8 ? 2 : 1;

/// Whether [word] may be corrected at all: long enough and in a script with
/// spaces between words.
bool isCorrectableWord(String word) =>
    word.runes.length >= typoMinLength && !_unspaced.hasMatch(word);

/// The optimal string alignment distance (insert, delete, replace and swap
/// of two neighbours) between [a] and [b], or null when it is above [max].
int? boundedTypoDistance(String a, String b, int max) =>
    _distance(a.runes.toList(), b.runes.toList(), max);

int? _distance(List<int> a, List<int> b, int max) {
  if ((a.length - b.length).abs() > max) return null;
  var beforePrev = List<int>.filled(b.length + 1, 0);
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final row = List<int>.filled(b.length + 1, 0)..[0] = i;
    var rowMin = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var d = prev[j - 1] + cost;
      if (prev[j] + 1 < d) d = prev[j] + 1;
      if (row[j - 1] + 1 < d) d = row[j - 1] + 1;
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        if (beforePrev[j - 2] + 1 < d) d = beforePrev[j - 2] + 1;
      }
      row[j] = d;
      if (d < rowMin) rowMin = d;
    }
    if (rowMin > max) return null; // no later row can come back under max
    beforePrev = prev;
    prev = row;
  }
  final d = prev[b.length];
  return d <= max ? d : null;
}

/// An indexed word and the number of songs holding it.
typedef VocabularyEntry = ({String term, int doc});

/// The words of the library, sorted, to look misspelt words up in. Keeps
/// each word as characters and bucketed by length, so a lookup only compares
/// the words whose length is within the allowed edits.
class TypoDictionary {
  /// Sorts and deduplicates [entries] (the larger `doc` wins).
  TypoDictionary(Iterable<VocabularyEntry> entries) {
    final byTerm = <String, int>{};
    for (final e in entries) {
      final seen = byTerm[e.term];
      if (seen == null || e.doc > seen) byTerm[e.term] = e.doc;
    }
    _terms = byTerm.keys.toList()..sort();
    _docs = [for (final t in _terms) byTerm[t]!];
    _runes = [for (final t in _terms) t.runes.toList(growable: false)];
    for (var i = 0; i < _runes.length; i++) {
      (_byLength[_runes[i].length] ??= <int>[]).add(i);
    }
  }

  late final List<String> _terms;
  late final List<int> _docs;
  late final List<List<int>> _runes;

  /// Indexes into [_terms] (ascending) per length in characters.
  final Map<int, List<int>> _byLength = {};

  int get length => _terms.length;
  bool get isEmpty => _terms.isEmpty;

  /// Whether some word starts with [prefix] (binary search).
  bool hasWordStartingWith(String prefix) {
    var lo = 0;
    var hi = _terms.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_terms[mid].compareTo(prefix) < 0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo < _terms.length && _terms[lo].startsWith(prefix);
  }

  /// The word to use instead of [word], or null when [word] needs none
  /// (too short, other script, or the start of a known word) or nothing is
  /// close. Closest first, then the word in most songs, then alphabetical.
  String? correct(String word) {
    if (!isCorrectableWord(word) || hasWordStartingWith(word)) return null;
    final chars = word.runes.toList(growable: false);
    final max = maxTypoDistance(chars.length);
    int? best;
    var bestDistance = max + 1;
    var bestDoc = -1;
    for (var len = chars.length - max; len <= chars.length + max; len++) {
      final bucket = _byLength[len];
      if (bucket == null) continue;
      for (final i in bucket) {
        final cap = bestDistance > max ? max : bestDistance;
        final d = _distance(chars, _runes[i], cap);
        if (d == null) continue;
        // Indexes follow the alphabetical order, so the lowest wins a tie.
        if (d < bestDistance ||
            (d == bestDistance &&
                (_docs[i] > bestDoc ||
                    (_docs[i] == bestDoc && (best == null || i < best))))) {
          best = i;
          bestDistance = d;
          bestDoc = _docs[i];
        }
      }
    }
    return best == null ? null : _terms[best];
  }
}

/// A request with its misspelt words replaced.
class TypoCorrection {
  const TypoCorrection(this.request, this.replacements);

  final SearchRequest request;

  /// Each replaced word and the word that stands in for it.
  final Map<String, String> replacements;
}

/// Whether any word of [request] could be corrected: tells whether the
/// dictionary is worth loading.
bool hasCorrectableWord(SearchRequest request) =>
    _words(request.query).any(isCorrectableWord);

Iterable<String> _words(ParsedSearchQuery q) => [
  ...q.freeTerms,
  for (final terms in q.fieldTerms.values) ...terms,
];

/// [request] with every misspelt word (free and `artist:`-style) replaced by
/// its closest word in [dictionary]; null when no word changed. A free word
/// for which [isKnownFreeWord] says true (e.g. a word of a file name the
/// search looks at) is not a typo and stays.
TypoCorrection? correctRequest(
  SearchRequest request,
  TypoDictionary dictionary, {
  bool Function(String word)? isKnownFreeWord,
}) {
  final replacements = <String, String>{};
  final memo = <String, String?>{};
  List<String> fix(List<String> terms, {required bool free}) => [
    for (final t in terms)
      if (free && (isKnownFreeWord?.call(t) ?? false))
        t
      else
        switch (memo.putIfAbsent(t, () => dictionary.correct(t))) {
          final c? => replacements[t] = c,
          null => t,
        },
  ];
  final q = request.query;
  final corrected = ParsedSearchQuery(
    freeTerms: fix(q.freeTerms, free: true),
    fieldTerms: {
      for (final e in q.fieldTerms.entries) e.key: fix(e.value, free: false),
    },
    years: q.years,
    formats: q.formats,
  );
  if (replacements.isEmpty) return null;
  return TypoCorrection(
    SearchRequest(query: corrected, fields: request.fields),
    replacements,
  );
}

/// [raw] with each word that has a replacement swapped for it. Words are
/// compared folded (see [searchWords]), so `Sonn` is replaced as `sonn`;
/// everything else, syntax included, stays as typed.
String correctedQueryText(String raw, Map<String, String> replacements) =>
    raw.replaceAllMapped(_wordRun, (m) {
      final words = searchWords(m[0]!);
      if (words.length != 1) return m[0]!;
      return replacements[words.single] ?? m[0]!;
    });

final _wordRun = RegExp(r'[\p{L}\p{N}\p{Co}]+', unicode: true);
