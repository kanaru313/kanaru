import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';

/// Every stored track, ordered by title, live. Empty when the library is
/// unavailable. The whole list is watched: fine for a minimal list, a
/// windowed query comes with the full songs page.
final songsListProvider = StreamProvider<List<TrackListItem>>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  return db == null ? Stream.value(const []) : db.watchTrackListItems();
});
