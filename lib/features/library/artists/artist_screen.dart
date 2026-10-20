import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/indexer/cover_paths.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../albums/album_grid_tile.dart';
import '../albums/album_tile_data.dart';
import '../library_detail_body.dart';
import '../library_route_keys.dart';
import '../play_tracks.dart';
import '../songs/song_tile.dart';
import '../widgets/artist_avatar.dart';
import 'artist_page_data.dart';
import 'artist_page_sections.dart';

/// One artist: header, then their albums, their songs, and the albums they
/// appear on. Tapping a song plays the Songs section from it. [routeKey]
/// comes from the URL; a broken key or an artist without tracks shows
/// "not found".
class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({super.key, required this.routeKey});

  final String routeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistKey = decodeArtistRouteKey(routeKey);
    return LibraryDetailBody<ArtistPageSections>(
      page: artistKey == null ? null : artistPageProvider(artistKey),
      what: 'the artist',
      notFound: const _ArtistNotFound(),
      builder: (sections) =>
          _ArtistPage(artistKey: artistKey!, sections: sections),
    );
  }
}

class _ArtistPage extends ConsumerWidget {
  const _ArtistPage({required this.artistKey, required this.sections});

  final String artistKey;
  final ArtistPageSections sections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final songs = sections.songs;
    final coverDirectory = ref.watch(coverCacheDirectoryProvider);
    final queue = [
      for (final t in songs)
        trackFromBrowse(t, artPath: coverPath(coverDirectory, t.coverKey)),
    ];
    void openAlbum(AlbumTileData album) =>
        context.go(artistAlbumLocation(artistKey, album.key));
    Widget heading(String text) => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
        child: Text(text, style: theme.textTheme.titleLarge),
      ),
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
            child: Row(
              children: [
                ArtistAvatar(
                  artistKey: artistKey,
                  name: sections.name,
                  size: 120,
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sections.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.artistsAlbumCount(sections.albumCount)} · '
                        '${l10n.albumsSongCount(songs.length)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => playTracks(ref, queue, 0),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(l10n.artistsPlay),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (sections.albums.isNotEmpty) ...[
          heading(l10n.artistsAlbums),
          SliverAlbumGrid(albums: sections.albums, onTap: openAlbum),
        ],
        heading(l10n.artistsSongs),
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
            onTap: () => playTracks(ref, queue, i),
          ),
        ),
        if (sections.appearsOn.isNotEmpty) ...[
          heading(l10n.artistsAppearsOn),
          SliverAlbumGrid(albums: sections.appearsOn, onTap: openAlbum),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _ArtistNotFound extends StatelessWidget {
  const _ArtistNotFound();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageScaffold(
      title: l10n.navArtists,
      body: EmptyState(
        icon: Icons.person_outline,
        title: l10n.artistsNotFound,
        message: l10n.artistsNotFoundMessage,
      ),
    );
  }
}
