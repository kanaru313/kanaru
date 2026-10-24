import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/indexer/cover_paths.dart';
import '../../../core/player/track.dart' as player;
import '../../../l10n/l10n.dart';
import '../../../shared/enqueue_tracks.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/library_route_keys.dart';
import '../../../shared/play_tracks.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/in_page_filter.dart';
import '../../../shared/in_page_filter_host.dart';
import '../../../shared/widgets/in_page_no_match.dart';
import '../albums/album_grid_tile.dart';
import '../albums/album_tile_data.dart';
import '../browse_songs_sliver.dart';
import '../library_detail_body.dart';
import 'genre_display_name.dart';
import 'genre_header.dart';
import 'genre_page_data.dart';

/// One genre: header, then its albums and its songs. Tapping a song plays the
/// songs from it. [routeKey] comes from the URL; a broken key or a genre
/// without tracks shows "not found".
class GenreScreen extends ConsumerWidget {
  const GenreScreen({super.key, required this.routeKey});

  final String routeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genreKey = decodeGenreRouteKey(routeKey);
    return LibraryDetailBody<GenrePageData>(
      page: genreKey == null ? null : genrePageProvider(genreKey),
      what: 'the genre',
      notFound: const _GenreNotFound(),
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

    return ListenableBuilder(
      listenable: _filter,
      builder: (context, _) {
        // Play and Shuffle in the header always take every song.
        final filtering = _filter.isFiltering;
        final shown = _view.apply(songs, _filter.terms);
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: GenreHeader(
                genreKey: widget.genreKey,
                name: name,
                albumCount: data.albums.length,
                songCount: songs.length,
                onPlay: () => playTracks(ref, queueOf(songs), 0),
                onShuffle: () => shuffleTracks(ref, queueOf(songs)),
                onQueueAction: (action) =>
                    enqueueLoaded(ref, context, action, queueOf(songs), name),
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
              SliverAlbumGrid(
                albums: data.albums,
                onTap: (AlbumTileData album) =>
                    context.go(albumLocation(album.key)),
                onQueueAction: (album, action) =>
                    enqueueAlbum(ref, context, action, album.key, album.title),
              ),
            ],
            SliverSongsHeading(title: l10n.genresSongs, filter: _filter),
            if (filtering && shown.isEmpty)
              SliverToBoxAdapter(child: InPageNoMatch(query: _filter.query))
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
  }
}

class _GenreNotFound extends StatelessWidget {
  const _GenreNotFound();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageScaffold(
      title: l10n.genresTitle,
      body: EmptyState(
        icon: AppIcons.genreOutlined,
        title: l10n.genresNotFound,
        message: l10n.genresNotFoundMessage,
      ),
    );
  }
}
