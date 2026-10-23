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
import '../../../shared/widgets/song_tile.dart';
import '../albums/album_grid_tile.dart';
import '../albums/album_tile_data.dart';
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

class _GenrePage extends ConsumerWidget {
  const _GenrePage({required this.genreKey, required this.data});

  final String genreKey;
  final GenrePageData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final songs = data.tracks;
    final name = genreDisplayName(l10n, genreKey, data.name);
    final coverDirectory = ref.watch(coverCacheDirectoryProvider);
    // Built when a track is tapped, not on every rebuild of a long page.
    List<player.Track> queue() => [
      for (final t in songs)
        trackFromBrowse(t, artPath: coverPath(coverDirectory, t.coverKey)),
    ];
    Widget heading(String text) => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
        child: Text(text, style: theme.textTheme.titleLarge),
      ),
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: GenreHeader(
            genreKey: genreKey,
            name: name,
            albumCount: data.albums.length,
            songCount: songs.length,
            onPlay: () => playTracks(ref, queue(), 0),
            onShuffle: () => shuffleTracks(ref, queue()),
            onQueueAction: (action) =>
                enqueueLoaded(ref, context, action, queue(), name),
          ),
        ),
        if (data.albums.isNotEmpty) ...[
          heading(l10n.genresAlbums),
          SliverAlbumGrid(
            albums: data.albums,
            onTap: (AlbumTileData album) =>
                context.go(albumLocation(album.key)),
            onQueueAction: (album, action) =>
                enqueueAlbum(ref, context, action, album.key, album.title),
          ),
        ],
        heading(l10n.genresSongs),
        SliverList.builder(
          itemCount: songs.length,
          itemBuilder: (context, i) => SongTile(
            song: TrackListItem(
              id: songs[i].id,
              path: songs[i].path,
              title: songs[i].title,
              artist: songs[i].artist,
              album: songs[i].album,
              durationMs: songs[i].durationMs,
              coverKey: songs[i].coverKey,
            ),
            onTap: () => playTracks(ref, queue(), i),
            onQueueAction: (action) => enqueueLoaded(ref, context, action, [
              trackFromBrowse(
                songs[i],
                artPath: coverPath(coverDirectory, songs[i].coverKey),
              ),
            ], songs[i].title),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
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
