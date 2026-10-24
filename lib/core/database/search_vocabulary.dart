import '../search/typo_correction.dart';
import 'library_database.dart';

/// The words of the search index, for correcting typos.
extension SearchVocabulary on LibraryDatabase {
  /// Every word `track_search` holds with the number of songs containing it.
  ///
  /// Read through a `temp` `fts5vocab` table, which lives only on this
  /// connection and so stays out of the schema; created here on each call
  /// (`IF NOT EXISTS`), which also covers a reopened connection. The 'row'
  /// kind lists whole words only, not the prefix index entries.
  Future<List<VocabularyEntry>> searchVocabulary() async {
    await customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS temp.track_search_vocab '
      "USING fts5vocab(main, 'track_search', 'row')",
    );
    final rows = await customSelect(
      'SELECT term, doc FROM temp.track_search_vocab',
    ).get();
    return [
      for (final row in rows)
        (term: row.read<String>('term'), doc: row.read<int>('doc')),
    ];
  }
}
