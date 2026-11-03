import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/playlist_modal_queries.dart';

/// Missing and repeated entry counts of one playlist plus its total length,
/// read once when a playlist or saved-queue modal opens (the clean-up rows
/// show only when their count is above zero; the saved-queue header shows
/// the length). Not tied to table updates or scans, so a rescan never makes
/// it read the whole playlist again. Null without a library.
final playlistModalStatsProvider = FutureProvider.autoDispose
    .family<PlaylistModalStats?, int>((ref, id) async {
      final db = ref.watch(libraryDatabaseProvider);
      return db?.playlistModalStats(id);
    });
