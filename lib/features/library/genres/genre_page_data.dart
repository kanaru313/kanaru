import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/genre_queries.dart';
import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/settings/library_sort.dart';
import '../../../core/database/throttled_tracks_query.dart';
import '../../../shared/library_browse_refresh.dart';
import '../albums/album_sort.dart';
import 'genres_provider.dart';

/// The order of the albums of a genre page: by title, then album key, as the
/// Albums tab breaks ties.
const genreAlbumsSort = SortChoice(AlbumSortField.title);

/// What a genre page shows: its name, the albums holding at least one of its
/// tracks (each as the Albums list shows it, in [genreAlbumsSort] order) and
/// its tracks by title.
class GenrePageData {
  const GenrePageData({
    required this.name,
    required this.albums,
    required this.tracks,
    required this.coverKeys,
  });

  final String name;
  final List<AlbumSummary> albums;
  final List<BrowseTrack> tracks;

  /// Up to four distinct cover keys for the header collage, from
  /// [genresProvider].
  final List<String> coverKeys;

  /// Length of all [tracks]; null when none has a known length.
  int? get durationMs {
    final known = tracks.map((t) => t.durationMs).nonNulls;
    return known.isEmpty ? null : known.fold<int>(0, (a, b) => a + b);
  }
}

/// What the page needs of a genre from the Genres list: its name, the
/// stored strings that name it, whether it also holds the tracks with no
/// genre, and its cover keys. Equal when all are, so a list reload that
/// changes none leaves the page alone.
class _GenreRaws {
  const _GenreRaws(this.name, this.raws, this.withoutGenre, this.coverKeys);

  final String name;
  final List<String> raws;
  final bool withoutGenre;
  final List<String> coverKeys;

  @override
  bool operator ==(Object other) =>
      other is _GenreRaws &&
      other.name == name &&
      other.withoutGenre == withoutGenre &&
      listEquals(other.raws, raws) &&
      listEquals(other.coverKeys, coverKeys);

  @override
  int get hashCode => Object.hash(
    name,
    withoutGenre,
    Object.hashAll(raws),
    Object.hashAll(coverKeys),
  );
}

/// Reads the page of the genre called [name], held by the stored strings
/// [raws] (and, with [includeNull], the tracks with no genre), in one
/// transaction. Null when no track is left in it.
Future<GenrePageData?> readGenrePage(
  LibraryDatabase db,
  String name,
  List<String> raws, {
  bool includeNull = false,
  List<String> coverKeys = const [],
}) => db.transaction(() async {
  final (tracks, albums) = await (
    db.genreTracks(raws, includeNull: includeNull),
    db.genreAlbums(raws, includeNull: includeNull),
  ).wait;
  if (tracks.isEmpty) return null;
  return GenrePageData(
    name: name,
    albums: sortAlbums(albums, genreAlbumsSort),
    tracks: tracks,
    coverKeys: coverKeys,
  );
});

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
            return found == null
                ? null
                : _GenreRaws(
                    found.name,
                    found.raws,
                    found.withoutGenre,
                    found.coverKeys,
                  );
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
        () => readGenrePage(
          db,
          raws.name,
          raws.raws,
          includeNull: raws.withoutGenre,
          coverKeys: raws.coverKeys,
        ),
        interval: ref.watch(libraryBrowseRefreshIntervalProvider),
      );
    });
