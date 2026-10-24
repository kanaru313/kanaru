import 'package:drift/drift.dart';

import 'home_query_sql.dart';
import 'library_browse_queries.dart'
    show albumSummaryFromRow, trackListItemFromRow;
import 'library_database.dart';

export 'home_query_sql.dart';

/// Reads of the Home page. Each is a one-shot `Future` with `limit` and
/// `offset`; the provider layer decides when to run it again. Tracks missing
/// from the library are left out, since Home is for playing.
extension HomeQueries on LibraryDatabase {
  /// Whether the library holds at least one track.
  Future<bool> homeHasTracks() async {
    final row = await customSelect(
      'SELECT EXISTS(SELECT 1 FROM tracks) AS has',
      readsFrom: {tracks},
    ).getSingle();
    return row.read<bool>('has');
  }

  /// Tracks by their latest listen, newest first, one row per track.
  Future<List<TrackListItem>> homeRecentlyPlayed({
    required int limit,
    int offset = 0,
  }) => customSelect(
    homeRecentlyPlayedSql,
    variables: [Variable.withInt(limit), Variable.withInt(offset)],
    readsFrom: {playStats, tracks},
  ).map(trackListItemFromRow).get();

  /// The latest `added_at` in the library, null when it is empty.
  Future<int?> homeNewestAddedAt() async {
    final row = await customSelect(
      'SELECT max(added_at) AS newest FROM tracks',
      readsFrom: {tracks},
    ).getSingle();
    return row.readNullable<int>('newest');
  }

  /// Tracks added at or after [since] (epoch ms; null means all), newest
  /// first, then newer file time, then id.
  Future<List<TrackListItem>> homeRecentlyAdded({
    int? since,
    required int limit,
    int offset = 0,
  }) => customSelect(
    homeRecentlyAddedSql,
    variables: [
      Variable<int>(since),
      Variable.withInt(limit),
      Variable.withInt(offset),
    ],
    readsFrom: {tracks},
  ).map(trackListItemFromRow).get();

  /// Tracks played in `[start, end)` (epoch ms), most plays first, then the
  /// latest play.
  Future<List<TrackListItem>> homeMemories({
    required int start,
    required int end,
    required int limit,
    int offset = 0,
  }) => customSelect(
    homeMemoriesSql,
    variables: [
      Variable.withInt(start),
      Variable.withInt(end),
      Variable.withInt(limit),
      Variable.withInt(offset),
    ],
    readsFrom: {plays, tracks},
  ).map(trackListItemFromRow).get();

  /// Albums by the latest listen of any of their tracks, each counted over
  /// all its tracks. Tracks without an album are ignored.
  Future<List<AlbumSummary>> homeRecentAlbums({
    required int limit,
    int offset = 0,
  }) => customSelect(
    homeRecentAlbumsSql,
    variables: [Variable.withInt(limit), Variable.withInt(offset)],
    readsFrom: {playStats, tracks},
  ).map(albumSummaryFromRow).get();

  /// Artists by the latest listen of any track crediting them.
  Future<List<ArtistCredit>> homeRecentArtists({
    required int limit,
    int offset = 0,
  }) =>
      customSelect(
            homeRecentArtistsSql,
            variables: [Variable.withInt(limit), Variable.withInt(offset)],
            readsFrom: {playStats, tracks, trackArtists},
          )
          .map(
            (row) => ArtistCredit(
              key: row.read<String>('artist_key'),
              name: row.read<String>('name'),
              trackCount: row.read<int>('n'),
              albumCount: row.read<int>('albums'),
            ),
          )
          .get();
}
