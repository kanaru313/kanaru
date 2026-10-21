import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/indexer/cover_paths.dart';
import '../../../core/player/track.dart' as player;
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../library_detail_body.dart';
import '../library_route_keys.dart';
import '../play_tracks.dart';
import 'album_header.dart';
import 'album_track_tile.dart';
import 'album_page_data.dart';

/// One album: header, then its tracks by disc. Tapping a track plays the
/// album from it. [routeKey] comes from the URL; a broken key or an album
/// that no longer exists shows "not found".
class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({super.key, required this.routeKey});

  final String routeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = decodeAlbumRouteKey(routeKey);
    return LibraryDetailBody<AlbumPageData>(
      page: key == null ? null : albumPageProvider(key),
      what: 'the album',
      notFound: const _AlbumNotFound(),
      builder: (data) => _AlbumPage(albumKey: key!, data: data),
    );
  }
}

class _AlbumPage extends ConsumerWidget {
  const _AlbumPage({required this.albumKey, required this.data});

  final AlbumKey albumKey;
  final AlbumPageData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final album = data.album;
    final tracks = data.tracks;
    final groups = data.groups;
    final coverDirectory = ref.watch(coverCacheDirectoryProvider);
    // Built when a track is tapped, not on every rebuild of a long page.
    List<player.Track> queue() => [
      for (final t in tracks)
        trackFromBrowse(t, artPath: coverPath(coverDirectory, t.coverKey)),
    ];
    final starts = data.groupStarts;
    final artistKey = data.linkedArtistKey;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: AlbumHeader(
            albumKey: albumKey,
            album: album,
            onPlay: () => playTracks(ref, queue(), 0),
            artist: artistKey != null && album.artist != null
                ? _ArtistLink(
                    name: album.artist!,
                    onTap: () => context.go(artistLocation(artistKey)),
                  )
                : null,
          ),
        ),
        for (final (g, group) in groups.indexed) ...[
          if (groups.length > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 4),
                child: Text(
                  group.disc == null
                      ? l10n.albumsUnknownDisc
                      : l10n.albumsDisc(group.disc!),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
          SliverList.builder(
            itemCount: group.tracks.length,
            itemBuilder: (context, i) => AlbumTrackTile(
              track: group.tracks[i],
              albumArtist: album.artist,
              onTap: () => playTracks(ref, queue(), starts[g] + i),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// The album artist's name, opening their page (in the Artists branch).
class _ArtistLink extends StatelessWidget {
  const _ArtistLink({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _AlbumNotFound extends StatelessWidget {
  const _AlbumNotFound();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageScaffold(
      title: l10n.navAlbums,
      body: EmptyState(
        icon: Icons.album_outlined,
        title: l10n.albumsNotFound,
        message: l10n.albumsNotFoundMessage,
      ),
    );
  }
}
