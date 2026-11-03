import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/genre_queries.dart';
import '../../core/database/library_browse_album_links.dart';
import '../../core/database/library_database.dart';
import '../../core/database/library_keys_provider.dart';
import '../../core/database/library_startup.dart';
import '../album_sort.dart';
import '../genre_summaries.dart';

/// What the genre modal links to: the albums and tracks of the genre, the local
/// folders holding those tracks, and the total duration.
typedef GenreLinks = ({
  List<AlbumSummary> albums,
  List<BrowseTrack> tracks,
  List<AlbumFolder> folders,
  int? durationMs,
});

/// The links of one genre; read once when the modal opens and not refreshed
/// by rescans while it is open. Null without a library or when no track has the
/// genre. Waits (stays pending) while the library keys are being rewritten,
/// then reads afresh once they are ready. A failed read is not retried, so the
/// rows grey out.
final genreModalLinksProvider = FutureProvider.autoDispose
    .family<GenreLinks?, GenreSummary>((ref, genre) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Future.value(null);
      if (!ref.watch(keysReadyProvider)) {
        return Completer<GenreLinks?>().future;
      }
      return db.transaction(() async {
        final (tracks, albums) = await (
          db.genreTracks(genre.raws, includeNull: genre.withoutGenre),
          db.genreAlbums(genre.raws, includeNull: genre.withoutGenre),
        ).wait;
        if (tracks.isEmpty) return null;
        final sortedAlbums = sortAlbums(albums, genreAlbumsSort);
        final folders = albumFoldersOf([for (final t in tracks) t.path]);
        final known = tracks.map((t) => t.durationMs).nonNulls;
        final durationMs = known.isEmpty
            ? null
            : known.fold<int>(0, (a, b) => a + b);
        return (
          albums: sortedAlbums,
          tracks: tracks,
          folders: folders,
          durationMs: durationMs,
        );
      });
    }, retry: (_, _) => null);
