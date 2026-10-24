/// Reads the search syntax: `artist:`, `album:`, `genre:`, `year:`,
/// `format:` and `language:` prefixes, values with spaces in double quotes.
/// Anything that does not parse as a filter stays plain text. Pure Dart.
library;

import '../database/search_terms.dart';
import '../indexer/audio_file_types.dart';
import 'search_query.dart';

/// The `field:` prefixes the search syntax recognizes, lower case. UI code
/// uses this to tell search syntax from a plain word that happens to contain
/// a colon.
const recognizedSearchPrefixes = {
  'artist',
  'album',
  'genre',
  'year',
  'format',
  'language',
};

/// One whitespace-separated piece of the query, quotes removed.
class _Token {
  _Token(this.text, this.colon);

  /// Full text without the quote characters.
  final String text;

  /// Index of the first `:` outside quotes, or -1.
  final int colon;
}

/// Splits [raw] on spaces outside double quotes. An unclosed quote runs to
/// the end of the string.
List<_Token> _tokenize(String raw) {
  final tokens = <_Token>[];
  final buf = StringBuffer();
  var colon = -1;
  var inQuotes = false;
  var started = false;

  void flush() {
    if (started) tokens.add(_Token(buf.toString(), colon));
    buf.clear();
    colon = -1;
    started = false;
  }

  for (final rune in raw.runes) {
    final ch = String.fromCharCode(rune);
    if (ch == '"') {
      inQuotes = !inQuotes;
      started = true;
    } else if (!inQuotes && ch.trim().isEmpty) {
      flush();
    } else {
      if (!inQuotes && ch == ':' && colon < 0) colon = buf.length;
      buf.write(ch);
      started = true;
    }
  }
  flush();
  return tokens;
}

final _yearRange = RegExp(r'^(\d{1,4})-(\d{1,4})$');
final _yearCompare = RegExp(r'^(>=|<=|>|<)(\d{1,4})$');
final _yearExact = RegExp(r'^(\d{1,4})$');

int? _validYear(String digits) {
  final year = int.parse(digits);
  return year >= 1 && year <= 9999 ? year : null;
}

/// The range for a `year:` value, or null when it is not one.
YearFilter? _parseYear(String value) {
  final exact = _yearExact.firstMatch(value);
  if (exact != null) {
    final y = _validYear(exact.group(1)!);
    return y == null ? null : YearFilter(min: y, max: y);
  }
  final range = _yearRange.firstMatch(value);
  if (range != null) {
    final a = _validYear(range.group(1)!);
    final b = _validYear(range.group(2)!);
    if (a == null || b == null) return null;
    return a <= b ? YearFilter(min: a, max: b) : YearFilter(min: b, max: a);
  }
  final compare = _yearCompare.firstMatch(value);
  if (compare != null) {
    final y = _validYear(compare.group(2)!);
    if (y == null) return null;
    return switch (compare.group(1)!) {
      '>' => YearFilter(min: y + 1),
      '>=' => YearFilter(min: y),
      '<' => YearFilter(max: y - 1),
      _ => YearFilter(max: y),
    };
  }
  return null;
}

/// The extension for a `format:` value, or null when it is not an audio one.
String? _parseFormat(String value) {
  final ext = value.toLowerCase();
  return audioExtensions.contains(ext) ? ext : null;
}

/// Which list a word goes to, in order of appearance (for the term cap).
typedef _Word = ({QueryField? field, String term});

/// Parses [raw]. Words from all places together are capped at
/// [maxSearchTerms]; the last ones are dropped.
ParsedSearchQuery parseSearchQuery(String raw) {
  final words = <_Word>[];
  final years = <YearFilter>[];
  final formats = <String>{};
  final languages = <String>[];

  void addText(QueryField? field, String text) {
    for (final term in searchWords(text)) {
      words.add((field: field, term: term));
    }
  }

  for (final token in _tokenize(raw)) {
    if (token.colon <= 0) {
      addText(null, token.text);
      continue;
    }
    final prefix = token.text.substring(0, token.colon).toLowerCase();
    final value = token.text.substring(token.colon + 1);
    final field = switch (prefix) {
      'artist' => QueryField.artist,
      'album' => QueryField.album,
      'genre' => QueryField.genre,
      _ => null,
    };
    if (field != null && searchWords(value).isNotEmpty) {
      addText(field, value);
    } else if (prefix == 'year' && _parseYear(value) != null) {
      years.add(_parseYear(value)!);
    } else if (prefix == 'format' && _parseFormat(value) != null) {
      formats.add(_parseFormat(value)!);
    } else if (prefix == 'language' && value.trim().isNotEmpty) {
      final language = value.trim();
      if (!languages.contains(language)) languages.add(language);
    } else {
      addText(null, token.text);
    }
  }

  final kept = words.length <= maxSearchTerms
      ? words
      : words.sublist(0, maxSearchTerms);
  final free = <String>[];
  final byField = <QueryField, List<String>>{};
  for (final word in kept) {
    if (word.field == null) {
      free.add(word.term);
    } else {
      (byField[word.field!] ??= []).add(word.term);
    }
  }
  return ParsedSearchQuery(
    freeTerms: List.unmodifiable(free),
    fieldTerms: Map.unmodifiable({
      for (final e in byField.entries)
        e.key: List<String>.unmodifiable(e.value),
    }),
    years: List.unmodifiable(years),
    formats: Set.unmodifiable(formats),
    languages: List.unmodifiable(languages),
  );
}
