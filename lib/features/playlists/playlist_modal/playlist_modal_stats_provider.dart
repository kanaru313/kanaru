import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/database/playlist_modal_queries.dart';

/// Missing and repeated entry counts of one playlist, read once when the
/// modal opens (a row each for Remove duplicates and Remove missing songs
/// shows only when its count is above zero). Not tied to table updates or
/// scans, so a rescan never makes it read the whole playlist again. Null
/// without a library.
final playlistModalStatsProvider = FutureProvider.autoDispose
    .family<PlaylistModalStats?, int>((ref, id) async {
      final db = ref.watch(libraryDatabaseProvider);
      return db?.playlistModalStats(id);
    });
