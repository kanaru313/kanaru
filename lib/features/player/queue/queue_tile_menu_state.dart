import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/database/library_browse_track_links.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/playlist_favorites.dart';

final _log = Logger('queue');

/// What the database says of the song at [path] when the menu opens: whether
/// it is a favorite and its library row. Both null without a library, for a
/// file that is not local or when a read fails (the menu is then cut down
/// to the queue rows and the file manager).
Future<({bool? favorite, ({int id, bool hasArtist, bool hasAlbum})? state})>
readQueueRowState(ProviderContainer container, String? path) async {
  final db = container.read(libraryDatabaseProvider);
  if (db == null || path == null) return (favorite: null, state: null);
  try {
    final (favorite, state) = await (
      db.isFavorite(path),
      db.trackMenuStateOfPath(path),
    ).wait;
    return (favorite: favorite, state: state);
  } catch (error, stack) {
    _log.warning('Reading a queue row for its menu failed', error, stack);
    return (favorite: null, state: null);
  }
}

/// Find lyrics online is offered for a local file, tagged or not, when the
/// library is open (a pick is stored there).
bool canFindLyricsForRow(ProviderContainer container, String? path) =>
    path != null && container.read(libraryDatabaseProvider) != null;
