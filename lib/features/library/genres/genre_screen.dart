import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/indexer/cover_paths.dart';
import '../../../core/player/track.dart' as player;
import '../../../l10n/l10n.dart';
import '../../../shared/enqueue_tracks.dart';
import '../../../shared/library_route_keys.dart';
import '../../../shared/play_tracks.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../../../shared/in_page_filter.dart';
import '../../../shared/in_page_filter_host.dart';
import '../../../shared/widgets/in_page_no_match.dart';
import '../albums/album_row.dart';
import '../albums/album_tile_data.dart';
import '../browse_songs_sliver.dart';
import '../library_detail_body.dart';
import '../../../shared/widgets/detail_page/cover_tint_page_background.dart';
import '../../../shared/widgets/detail_page/detail_side_pane.dart';
import '../../../shared/widgets/detail_page/tracks_toolbar.dart';
import 'genre_display_name.dart';
import 'genre_header.dart';
import 'genre_not_found.dart';
import 'genre_page_data.dart';

/// One genre: header, then its albums on one line scrolling sideways, then its
/// songs. A wide window puts the header in a side pane beside the rest.
/// Tapping a song plays the songs from it. [routeKey] comes from the URL; a
/// broken key or a genre without tracks shows "not found".
class GenreScreen extends ConsumerWidget {
  const GenreScreen({super.key, required this.routeKey});

  final String routeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genreKey = decodeGenreRouteKey(routeKey);
    return LibraryDetailBody<GenrePageData>(
      page: genreKey == null ? null : genrePageProvider(genreKey),
      what: 'the genre',
      notFound: const GenreNotFound(),
      builder: (data) => _GenrePage(genreKey: genreKey!, data: data),
    );
  }
}

class _GenrePage extends ConsumerStatefulWidget {
  const _GenrePage({required this.genreKey, required this.data});

  final String genreKey;
  final GenrePageData data;

  @override
  ConsumerState<_GenrePage> createState() => _GenrePageState();
}

class _GenrePageState extends ConsumerState<_GenrePage>
    with InPageFilterHost<_GenrePage> {
  /// The filter dies with the page, so leaving it clears it.
  final _filter = InPageFilterController();

  @override
  InPageFilterController get filterController => _filter;

  final _view = InPageFilterView<BrowseTrack>(
    (t) => (title: t.title, artist: t.artist, album: t.album),
  );

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final data = widget.data;
    final songs = data.tracks;
    final name = genreDisplayName(l10n, widget.genreKey, data.name);
    final coverDirectory = ref.watch(coverCacheDirectoryProvider);
    // Built when a track is tapped, not on every rebuild of a long page.
    List<player.Track> queueOf(List<BrowseTrack> list) => [
      for (final t in list)
        trackFromBrowse(t, artPath: coverPath(coverDirectory, t.coverKey)),
    ];

    // Play and Shuffle in the header always take every song.
    void onPlay() => playTracks(ref, queueOf(songs), 0);
    void onShuffle() => shuffleTracks(ref, queueOf(songs));
    void onQueueAction(QueueAction action) =>
        enqueueLoaded(ref, context, action, queueOf(songs), name);

    return CoverTintPageBackground.blend(
      coverKeys: data.coverKeys,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= detailSidePaneMinPageWidth;
          final content = ListenableBuilder(
            listenable: _filter,
            builder: (context, _) {
              final filtering = _filter.isFiltering;
              final shown = _view.apply(songs, _filter.terms);
              return CustomScrollView(
                slivers: [
                  if (!wide)
                    SliverToBoxAdapter(
                      child: GenreHeader(
                        genreKey: widget.genreKey,
                        name: name,
                        albumCount: data.albums.length,
                        songCount: songs.length,
                        coverKeys: data.coverKeys,
                        onPlay: onPlay,
                        onShuffle: onShuffle,
                        onQueueAction: onQueueAction,
                      ),
                    ),
                  if (!filtering && data.albums.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
                        child: Text(
                          l10n.genresAlbums,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ),
                    SliverAlbumRow(
                      albums: data.albums,
                      onTap: (AlbumTileData album) =>
                          context.go(albumLocation(album.key)),
                      onQueueAction: (album, action) => enqueueAlbum(
                        ref,
                        context,
                        action,
                        album.key,
                        album.title,
                      ),
                    ),
                  ],
                  SliverTracksToolbar(
                    songCount: songs.length,
                    durationMs: data.durationMs,
                    filter: _filter,
                  ),
                  if (filtering && shown.isEmpty)
                    SliverToBoxAdapter(
                      child: InPageNoMatch(query: _filter.query),
                    )
                  else
                    SliverBrowseSongs(
                      songs: shown,
                      onTap: (i) => playTracks(ref, queueOf(shown), i),
                      onQueueAction: (song, action) => enqueueLoaded(
                        ref,
                        context,
                        action,
                        queueOf([song]),
                        song.title,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              );
            },
          );
          if (!wide) return content;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GenreSidePane(
                genreKey: widget.genreKey,
                name: name,
                albumCount: data.albums.length,
                songCount: songs.length,
                coverKeys: data.coverKeys,
                onPlay: onPlay,
                onShuffle: onShuffle,
                onQueueAction: onQueueAction,
              ),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}
