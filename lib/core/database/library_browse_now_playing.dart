import 'package:drift/drift.dart';

import 'library_database.dart';

/// The album of the playing song: the tag text and, when the album has a
/// page, its key.
class NowPlayingAlbum {
  const NowPlayingAlbum({required this.title, required this.key});

  final String title;

  /// Null when the row carries no album key (nothing to open).
  final AlbumKey? key;
}

extension LibraryBrowseNowPlaying on LibraryDatabase {
  /// The album of the library row at [path]; null when the file is not in the
  /// library or its album tag is missing or blank. The key follows the rule
  /// of the album page.
  Future<NowPlayingAlbum?> albumOfPath(String path) async {
    final row = await customSelect(
      'SELECT album, album_artist_key AS ak, album_title_key AS tk '
      'FROM tracks WHERE path = ?1',
      variables: [Variable(path)],
      readsFrom: {tracks},
    ).getSingleOrNull();
    final title = row?.readNullable<String>('album')?.trim();
    if (row == null || title == null || title.isEmpty) return null;
    final titleKey = row.readNullable<String>('tk');
    return NowPlayingAlbum(
      title: title,
      key: titleKey == null
          ? null
          : AlbumKey(row.readNullable<String>('ak') ?? '', titleKey),
    );
  }
}
