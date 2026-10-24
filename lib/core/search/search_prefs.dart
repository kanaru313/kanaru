/// What the search remembers between runs: recent queries and the fields the
/// free text looks at. Pure Dart; `search_prefs_file.dart` stores it.
library;

import 'search_fields.dart';

/// Most queries kept.
const searchHistoryLimit = 20;

/// Longest query kept, in characters (code points); longer ones are cut.
const searchHistoryEntryMaxLength = 500;

/// Immutable; every operation returns the new value.
class SearchPrefs {
  /// [fields] defaults to [defaultSearchFields] when null.
  // A private field cannot be a named initializing formal.
  const SearchPrefs({this.history = const [], Set<SearchField>? fields})
    // ignore: prefer_initializing_formals
    : _fields = fields;

  final Set<SearchField>? _fields;

  /// Recent queries, newest first.
  final List<String> history;

  /// Fields the free text of a search looks at; never empty.
  Set<SearchField> get fields => _fields ?? defaultSearchFields;

  /// Puts [raw] first. A query equal to an older one (ignoring case and
  /// surrounding spaces) replaces it, keeping the new spelling. Blank queries
  /// change nothing.
  SearchPrefs record(String raw) {
    final entry = _clean(raw);
    if (entry.isEmpty) return this;
    final key = entry.toLowerCase();
    return SearchPrefs(
      history: [
        entry,
        for (final old in history)
          if (old.toLowerCase() != key) old,
      ].take(searchHistoryLimit).toList(growable: false),
      fields: fields,
    );
  }

  /// Drops [entry] (compared ignoring case and surrounding spaces).
  SearchPrefs remove(String entry) {
    final key = entry.trim().toLowerCase();
    final kept = [
      for (final old in history)
        if (old.toLowerCase() != key) old,
    ];
    if (kept.length == history.length) return this;
    return SearchPrefs(history: kept, fields: fields);
  }

  /// Empties the history; the same instance when it is already empty.
  SearchPrefs clear() => history.isEmpty ? this : SearchPrefs(fields: fields);

  /// Uses [chosen] as the fields. An empty set is refused: the old fields
  /// stay.
  /// The same instance when [chosen] equals the current fields.
  SearchPrefs withFields(Set<SearchField> chosen) =>
      chosen.isEmpty ||
          (chosen.length == fields.length && fields.containsAll(chosen))
      ? this
      : SearchPrefs(history: history, fields: Set.unmodifiable(chosen));

  /// Trimmed and cut to [searchHistoryEntryMaxLength].
  static String _clean(String raw) {
    final trimmed = raw.trim();
    final runes = trimmed.runes;
    return runes.length <= searchHistoryEntryMaxLength
        ? trimmed
        : String.fromCharCodes(runes.take(searchHistoryEntryMaxLength)).trim();
  }

  /// [_clean] for decoded data.
  static String cleanEntry(String raw) => _clean(raw);
}
