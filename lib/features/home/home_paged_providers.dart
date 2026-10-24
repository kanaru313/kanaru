import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/home_queries.dart';
import '../../core/database/home_windows.dart';
import '../../core/database/library_database.dart';
import 'home_paged_list.dart';

typedef HomeTrackPages =
    NotifierProvider<
      HomePagedList<TrackListItem>,
      HomePagedState<TrackListItem>
    >;

/// Songs added inside [HomeAddedWindow], newest first.
final homeRecentlyAddedPagesProvider = NotifierProvider.autoDispose
    .family<
      HomePagedList<TrackListItem>,
      HomePagedState<TrackListItem>,
      HomeAddedWindow
    >(
      (window) => HomePagedList<TrackListItem>(
        read: (db, now, limit, offset) => db.homeRecentlyAdded(
          since: addedWindowSince(window, now),
          limit: limit,
          offset: offset,
        ),
        keyOf: (row) => row.id,
      ),
    );

/// Songs played around today's date last year, most played first.
final homeMemoriesPagesProvider =
    NotifierProvider.autoDispose<
      HomePagedList<TrackListItem>,
      HomePagedState<TrackListItem>
    >(
      () => HomePagedList<TrackListItem>(
        read: (db, now, limit, offset) {
          final window = memoriesWindow(now);
          return db.homeMemories(
            start: window.start,
            end: window.end,
            limit: limit,
            offset: offset,
          );
        },
        keyOf: (row) => row.id,
      ),
    );

/// Albums by their latest listen.
final homeRecentAlbumsPagesProvider =
    NotifierProvider.autoDispose<
      HomePagedList<AlbumSummary>,
      HomePagedState<AlbumSummary>
    >(
      () => HomePagedList<AlbumSummary>(
        read: (db, now, limit, offset) =>
            db.homeRecentAlbums(limit: limit, offset: offset),
        keyOf: (row) => '${row.key.artistKey}\u0000${row.key.titleKey}',
      ),
    );

/// Artists by their latest listen.
final homeRecentArtistsPagesProvider =
    NotifierProvider.autoDispose<
      HomePagedList<ArtistCredit>,
      HomePagedState<ArtistCredit>
    >(
      () => HomePagedList<ArtistCredit>(
        read: (db, now, limit, offset) =>
            db.homeRecentArtists(limit: limit, offset: offset),
        keyOf: (row) => row.key,
      ),
    );
