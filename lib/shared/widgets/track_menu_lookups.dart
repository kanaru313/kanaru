import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../core/database/library_rows.dart';
import '../../core/database/library_startup.dart';
import '../../core/database/playlist_favorites.dart';
import '../../core/lyrics/online/lyrics_target.dart';

final _log = Logger('track_actions_menu');

/// What Find lyrics online searches for; null (no row) for a song without
/// a real title (the file-name placeholder), one that is not a local file,
/// without the library row [song], or without a library, where a pick could
/// not be kept.
LyricsTarget? menuLyricsTarget(WidgetRef ref, TrackListItem? song) {
  if (song == null || ref.read(libraryDatabaseProvider) == null) return null;
  final target = LyricsTarget.fromListItem(song);
  return target.path == null || target.query.title == null ? null : target;
}

/// Whether [path] is in Favorites; null without a library or when the read
/// fails (the menu then leaves the row out).
Future<bool?> menuIsFavorite(WidgetRef ref, String path) async {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return null;
  try {
    return await db.isFavorite(path);
  } catch (error, stack) {
    _log.warning('Reading whether a song is a favorite failed', error, stack);
    return null;
  }
}
