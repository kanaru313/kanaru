import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/indexer/cover_paths.dart';
import '../../../core/player/track.dart' as player;
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../library_detail_body.dart';
import '../widgets/cover_tint_page_background.dart';
import '../widgets/detail_side_pane.dart';
import '../widgets/tracks_toolbar.dart';
import '../../../shared/library_route_keys.dart';
import '../../../shared/enqueue_tracks.dart';
import '../../../shared/play_tracks.dart';
import '../../../shared/in_page_filter.dart';
import '../../../shared/in_page_filter_host.dart';
import 'album_artist_link.dart';
import 'album_filtered_tracks.dart';
import 'album_header.dart';
import 'album_side_pane.dart';
import 'album_track_tile.dart';
import 'album_page_data.dart';

/// One album: header, then its tracks by disc; a wide window puts the
/// header in a side pane beside the tracks. Tapping a track plays the
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

class _AlbumPage extends ConsumerStatefulWidget {
  const _AlbumPage({required this.albumKey, required this.data});

  final AlbumKey albumKey;
  final AlbumPageData data;

  @override
  ConsumerState<_AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends ConsumerState<_AlbumPage>
    with InPageFilterHost<_AlbumPage> {
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
    final l10n = context.l10n;
    final data = widget.data;
    final album = data.album;
    final tracks = data.tracks;
    final groups = data.groups;
    final coverDirectory = ref.watch(coverCacheDirectoryProvider);
    // Built when a track is tapped, not on every rebuild of a long page.
    List<player.Track> queueOf(List<BrowseTrack> list) => [
      for (final t in list)
        trackFromBrowse(t, artPath: coverPath(coverDirectory, t.coverKey)),
    ];
    final starts = data.groupStarts;
    final artistKey = data.linkedArtistKey;
    void enqueueOne(BrowseTrack t, QueueAction action) =>
        enqueueLoaded(ref, context, action, queueOf([t]), t.title);

    void onPlay() => playTracks(ref, queueOf(tracks), 0);
    void onShuffle() => shuffleTracks(ref, queueOf(tracks));
    void onQueueAction(QueueAction action) =>
        enqueueLoaded(ref, context, action, queueOf(tracks), album.title);
    final artistLink = artistKey != null && album.artist != null
        ? AlbumArtistLink(
            name: album.artist!,
            onTap: () => context.go(artistLocation(artistKey)),
          )
        : null;

    return CoverTintPageBackground(
      coverKey: album.coverKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= detailSidePaneMinPageWidth;
          final tracksView = ListenableBuilder(
            listenable: _filter,
            builder: (context, _) {
              final filtering = _filter.isFiltering;
              final shown = _view.apply(tracks, _filter.terms);
              return CustomScrollView(
                slivers: [
                  if (!wide)
                    SliverToBoxAdapter(
                      child: AlbumHeader(
                        albumKey: widget.albumKey,
                        album: album,
                        onPlay: onPlay,
                        onShuffle: onShuffle,
                        onQueueAction: onQueueAction,
                        artist: artistLink,
                      ),
                    ),
                  SliverTracksToolbar(
                    title: l10n.albumsSongs,
                    songCount: album.trackCount,
                    durationMs: album.durationMs,
                    filter: _filter,
                  ),
                  if (filtering)
                    SliverAlbumFilteredTracks(
                      tracks: shown,
                      query: _filter.query,
                      onTap: (i) => playTracks(ref, queueOf(shown), i),
                      onQueueAction: enqueueOne,
                    )
                  else
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
                          onTap: () =>
                              playTracks(ref, queueOf(tracks), starts[g] + i),
                          onQueueAction: (action) =>
                              enqueueOne(group.tracks[i], action),
                        ),
                      ),
                    ],
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              );
            },
          );
          if (!wide) return tracksView;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AlbumSidePane(
                albumKey: widget.albumKey,
                album: album,
                onPlay: onPlay,
                onShuffle: onShuffle,
                onQueueAction: onQueueAction,
                artist: artistLink,
              ),
              Expanded(child: tracksView),
            ],
          );
        },
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
        icon: AppIcons.albumOutlined,
        title: l10n.albumsNotFound,
        message: l10n.albumsNotFoundMessage,
      ),
    );
  }
}
