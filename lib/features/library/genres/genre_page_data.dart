import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/genre_queries.dart';
import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/text_keys.dart';
import '../../../core/database/throttled_tracks_query.dart';
import '../../../shared/library_browse_refresh.dart';
import '../../../shared/sort_compare.dart';
import '../albums/album_tile_data.dart';
import 'genres_provider.dart';

/// What a genre page shows: its name, the albums holding at least one of its
/// tracks (each as the Albums list shows it) and its tracks by title.
class GenrePageData {
  const GenrePageData({
    required this.name,
    required this.albums,
    required this.tracks,
  });

  final String name;
  final List<AlbumTileData> albums;
  final List<BrowseTrack> tracks;
}

/// What the page needs of a genre from the Genres list: its name and the
/// stored strings that name it. Equal when both are, so a list reload that
/// changes neither leaves the page alone.
class _GenreRaws {
  const _GenreRaws(this.name, this.raws);

  final String name;
  final List<String> raws;

  @override
  bool operator ==(Object other) =>
      other is _GenreRaws && other.name == name && listEquals(other.raws, raws);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(raws));
}

/// Reads the page of the genre called [name], held by the stored strings
/// [raws], in one transaction. Null when no track is left in it.
Future<GenrePageData?> readGenrePage(
  LibraryDatabase db,
  String name,
  List<String> raws,
) => db.transaction(() async {
  final (tracks, albums) = await (
    db.genreTracks(raws),
    db.genreAlbums(raws),
  ).wait;
  if (tracks.isEmpty) return null;
  albums.sort(_byTitle);
  return GenrePageData(
    name: name,
    albums: [for (final a in albums) AlbumTileData.fromSummary(a)],
    tracks: tracks,
  );
});

/// Title sort key, then the album key.
int _byTitle(AlbumSummary a, AlbumSummary b) {
  final title = compareCodePoints(
    a.titleSort ?? sortKey(a.title),
    b.titleSort ?? sortKey(b.title),
  );
  if (title != 0) return title;
  final artist = compareCodePoints(a.key.artistKey, b.key.artistKey);
  return artist != 0
      ? artist
      : compareCodePoints(a.key.titleKey, b.key.titleKey);
}

/// The page of one genre (by key), reloaded at most every
/// [libraryBrowseRefreshIntervalProvider] while the library changes. The
/// stored strings of the genre come from [genresProvider] (shared with the
/// list, so the page never groups the whole table itself); it follows them
/// when a retag adds or drops one. Null when no track has the genre any more.
/// Disposed when its page closes.
final genrePageProvider = StreamProvider.autoDispose
    .family<GenrePageData?, String>((ref, genreKey) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(null);
      final genre = ref.watch(
        genresProvider.select(
          (genres) => genres.whenData((list) {
            final found = list.where((g) => g.key == genreKey).firstOrNull;
            return found == null ? null : _GenreRaws(found.name, found.raws);
          }),
        ),
      );
      if (genre.hasError) return Stream.error(genre.error!, genre.stackTrace!);
      // Not loaded yet (or the keys are still being made).
      if (!genre.hasValue) return const Stream.empty();
      final raws = genre.requireValue;
      if (raws == null) return Stream.value(null);
      return throttledTracksQuery(
        db,
        () => readGenrePage(db, raws.name, raws.raws),
        interval: ref.watch(libraryBrowseRefreshIntervalProvider),
      );
    });
