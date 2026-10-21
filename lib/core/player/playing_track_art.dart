import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/library_database.dart';
import '../database/library_startup.dart';
import '../database/throttled_tracks_query.dart';
import '../database/track_cover_lookup.dart';
import '../indexer/cover_paths.dart';
import 'player_service.dart';

final _log = Logger('playing_art');

/// Local file path of a track uri, or `null`. A plain absolute path is
/// returned as is; a `file://` uri without a host is decoded. Anything else,
/// malformed uris included, gives `null`. Never throws. No symlink
/// normalization: a path spelled differently from the library row is not
/// found, and its art falls back like a non-library track's.
String? localPathOf(String uri) {
  if (uri.startsWith('/')) return uri;
  final parsed = Uri.tryParse(uri);
  if (parsed == null || parsed.scheme != 'file' || parsed.host.isNotEmpty) {
    return null;
  }
  try {
    return parsed.toFilePath();
  } on Object {
    // An encoded slash (`%2F`) and the like have no file path.
    return null;
  }
}

/// Whether [art] names a thumbnail inside [directory]:
/// `<directory>/<a well-formed cover key>`.
bool isCoverPathIn(String directory, String? art) =>
    art != null &&
    art.startsWith('$directory/') &&
    isCoverKey(art.substring(directory.length + 1));

/// The library row at [path] as `(coverKey: …)`, followed while `tracks`
/// changes; `null` when no library track has this path.
///
/// Loads on listen and once after each change, never two loads at once and
/// never cancelling one, so a result arrives even while a scan writes. Retry
/// is off: the next change loads again anyway. A failure is logged once per
/// run of failures.
final libraryCoverKeyProvider = StreamProvider.autoDispose
    .family<({String? coverKey})?, String>((ref, path) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(null);
      return _followCoverKey(db, path);
    }, retry: (_, _) => null);

Stream<({String? coverKey})?> _followCoverKey(LibraryDatabase db, String path) {
  var failing = false;
  return throttledTracksQuery(db, () async {
    try {
      final row = await db.coverKeyOf(path);
      failing = false;
      return row;
    } catch (error, stackTrace) {
      if (!failing) {
        _log.warning('Looking up the playing cover failed', error, stackTrace);
      }
      failing = true;
      rethrow;
    }
  }, interval: Duration.zero).distinct();
}

/// Art for the playing track, as the player bar, Now Playing and MPRIS show
/// it. The queue keeps the art a track was queued with; the library may have
/// made or replaced its cover since, so a library track follows its row:
///
/// - library row found: its cover thumbnail, `null` when it has none;
/// - first lookup still pending: the queued art only if it is one of our
///   thumbnails, else `null`;
/// - no row for the path, no library, covers off, or not a local file: the
///   queued art;
/// - lookup failed: the last value for this path, else the pending rule.
final playingTrackArtProvider = Provider<String?>((ref) {
  // Tracks compare by uri: this recomputes on a track change, not on every
  // new queue.
  final track = ref.watch(playerServiceProvider.select((s) => s.queue.current));
  if (track == null) return null;
  final directory = ref.watch(coverCacheDirectoryProvider);
  final db = ref.watch(libraryDatabaseProvider);
  final path = localPathOf(track.uri);
  if (directory == null || db == null || path == null) return track.artUri;
  final found = ref.watch(libraryCoverKeyProvider(path));
  if (found.hasValue) {
    final row = found.value;
    return row == null ? track.artUri : coverPath(directory, row.coverKey);
  }
  return isCoverPathIn(directory, track.artUri) ? track.artUri : null;
});
