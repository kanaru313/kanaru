import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'library_startup.dart';
import 'playlist_queries.dart';
import 'playlist_rows.dart';

/// Every playlist, newest first; empty without a library. Shared by the
/// sidebar, the add-to-playlist picker and the playlists page. Not
/// auto-disposed: the sidebar keeps it alive for the life of the app.
final playlistSummariesProvider = StreamProvider<List<PlaylistSummary>>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  return db == null ? Stream.value(const []) : db.watchPlaylistSummaries();
});
