/// Resolves `language:` values to the raw `tracks.language` strings they
/// match. Tags are stored as written (`vie`, `Vietnamese; English`), so the
/// match is done in Dart on the few distinct raw values with the same helpers
/// that group languages elsewhere, then handed to SQL as an exact list.
library;

import 'language_tags.dart';
import 'library_database.dart';

/// Every distinct non-null raw language tag in the library. Uses the
/// `tracks_language` index.
Future<List<String>> loadDistinctLanguages(LibraryDatabase db) async {
  final rows = await db
      .customSelect(
        'SELECT DISTINCT language FROM tracks WHERE language IS NOT NULL',
        readsFrom: {db.tracks},
      )
      .get();
  return [for (final row in rows) row.read<String>('language')];
}

/// The raw tags in [distinct] that list at least one of [wanted] (compared by
/// language key). Empty when nothing matches; the caller then has no songs.
List<String> matchingLanguageValues(
  Iterable<String> distinct,
  Iterable<String> wanted,
) {
  final keys = {for (final w in wanted) languageKey(w)};
  if (keys.isEmpty) return const [];
  return [
    for (final raw in distinct)
      if (splitLanguages(raw).any((v) => keys.contains(languageKey(v)))) raw,
  ];
}
