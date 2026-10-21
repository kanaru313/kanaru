import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/artist_names.dart';
import '../../../core/database/library_browse_queries.dart';
import '../../../core/database/library_database.dart';
import '../../../core/database/library_keys_provider.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/throttled_tracks_query.dart';
import '../../../shared/library_browse_refresh.dart';
import 'album_disc_groups.dart';

/// Everything the album page shows: the album's details (the albums query
/// row, so the page agrees with the Albums list), its tracks by disc then
/// track, and what the page derives from them.
class AlbumPageData {
  AlbumPageData({
    required AlbumKey key,
    required this.album,
    required this.tracks,
  }) : groups = groupByDisc(tracks),
       linkedArtistKey = _linkedArtistKey(key, tracks);

  final AlbumSummary album;
  final List<BrowseTrack> tracks;

  /// [tracks] split by disc, in display order.
  final List<DiscGroup> groups;

  /// The key of the album artist when their page can be opened: only when a
  /// track here credits them, as a name found only as album artist (for
  /// example "Various Artists") has no artist page. Else null.
  final String? linkedArtistKey;

  /// Where each of [groups] starts in [tracks].
  late final List<int> groupStarts = () {
    final starts = <int>[];
    var count = 0;
    for (final group in groups) {
      starts.add(count);
      count += group.tracks.length;
    }
    return starts;
  }();
}

String? _linkedArtistKey(AlbumKey key, List<BrowseTrack> tracks) {
  final artistKey = key.artistKeys.firstOrNull;
  return artistKey != null &&
          tracks.any((t) => artistKeys(t.artist).contains(artistKey))
      ? artistKey
      : null;
}

/// The page data of one album, read in one transaction (both queries see the
/// same library) and reloaded at most every
/// [libraryBrowseRefreshIntervalProvider] while the library changes. It has a
/// value only when the details and the tracks are both there; null when the
/// album no longer has tracks. Disposed when its page closes.
final albumPageProvider = StreamProvider.autoDispose
    .family<AlbumPageData?, AlbumKey>((ref, key) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(null);
      // Wait for the keys: becoming ready rebuilds this and loads afresh.
      if (!ref.watch(keysReadyProvider)) return const Stream.empty();
      return throttledTracksQuery(
        db,
        () => db.transaction(() async {
          final (album, tracks) = await (
            db.album(key),
            db.albumTracks(key),
          ).wait;
          return album == null || tracks.isEmpty
              ? null
              : AlbumPageData(key: key, album: album, tracks: tracks);
        }),
        interval: ref.watch(libraryBrowseRefreshIntervalProvider),
      );
    });
