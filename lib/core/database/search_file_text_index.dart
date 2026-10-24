import 'dart:isolate';

import 'library_database.dart';
import 'search_terms.dart';

/// One track's id, path and comment: what the index is built from.
typedef FileTextRow = ({int id, String path, String? comment});

class _Entry {
  _Entry(this.id, this.fileWords, this.commentWords);

  final int id;
  final List<String> fileWords;
  final List<String> commentWords;
}

/// The words of file names and comments, folded like the stored search
/// columns, so a plain search can look at them although the full-text index
/// does not hold them. Built once from the tracks (fold in a background
/// isolate, a library is tens of thousands of paths) and matched in memory.
class SearchFileTextIndex {
  SearchFileTextIndex._(this._entries);

  /// Reads every track of [db] and builds the index.
  static Future<SearchFileTextIndex> load(LibraryDatabase db) async {
    final rows = await db
        .customSelect('SELECT id, path, comment FROM tracks ORDER BY id')
        .get();
    return build([
      for (final row in rows)
        (
          id: row.read<int>('id'),
          path: row.read<String>('path'),
          comment: row.read<String?>('comment'),
        ),
    ]);
  }

  /// Builds the index of [rows] in a background isolate.
  static Future<SearchFileTextIndex> build(List<FileTextRow> rows) =>
      Isolate.run(() => buildNow(rows));

  /// Builds the index of [rows] on the calling isolate.
  static SearchFileTextIndex buildNow(List<FileTextRow> rows) =>
      SearchFileTextIndex._([
        for (final row in rows)
          _Entry(
            row.id,
            searchWords(fileNameOf(row.path)),
            searchWords(row.comment ?? ''),
          ),
      ]);

  final List<_Entry> _entries;

  /// Tracks indexed.
  int get length => _entries.length;

  /// Ids of the tracks where every term of [terms] is the prefix of a word
  /// in the file name (when [fileName]) or in the comment (when [comment]),
  /// in id order. No terms or no field matches nothing.
  List<int> match(
    List<String> terms, {
    bool fileName = false,
    bool comment = false,
  }) {
    if (terms.isEmpty || !(fileName || comment)) return const [];
    return [
      for (final e in _entries)
        if (termsMatch([
          if (fileName) ...e.fileWords,
          if (comment) ...e.commentWords,
        ], terms))
          e.id,
    ];
  }
}

/// The file name of [path] without its folder or its extension: the folder
/// names do not count as the song's own words.
String fileNameOf(String path) {
  final slash = path.lastIndexOf(RegExp(r'[/\\]'));
  final name = slash < 0 ? path : path.substring(slash + 1);
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}
