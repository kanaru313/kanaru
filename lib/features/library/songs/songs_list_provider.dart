import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/library_browse_queries.dart';
import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/settings/settings_provider.dart';

/// Every stored track in the saved Songs sort, live. Empty when the library
/// is unavailable. The whole list is watched: fine for a minimal list, a
/// windowed query comes with the full songs page.
final songsListProvider = StreamProvider<List<TrackListItem>>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  final sort = ref.watch(settingsProvider.select((s) => s.songSort));
  return db == null
      ? Stream.value(const [])
      : db.watchSongs(
          order: songOrderFor(sort.field),
          descending: sort.descending,
        );
});

/// The database order for a Songs sort field (the database does not know
/// the settings).
SongOrder songOrderFor(SongSortField field) => switch (field) {
  SongSortField.title => SongOrder.title,
  SongSortField.artist => SongOrder.artist,
  SongSortField.album => SongOrder.album,
  SongSortField.year => SongOrder.year,
  SongSortField.dateAdded => SongOrder.dateAdded,
  SongSortField.duration => SongOrder.duration,
};
