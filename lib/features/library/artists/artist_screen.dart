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
import 'artist_header.dart';
import 'artist_page_data.dart';
import 'artist_page_sections.dart';

/// One artist: header, then their albums and the albums they appear on,
/// each as one line scrolling sideways, then their songs. A wide window
/// puts the header in a side pane beside the rest. Tapping a song plays the
/// Songs section from it. [routeKey]
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

class _ArtistPage extends ConsumerStatefulWidget {
  const _ArtistPage({required this.artistKey, required this.sections});

  final String artistKey;
  final ArtistPageSections sections;

  @override
  ConsumerState<_ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends ConsumerState<_ArtistPage>
    with InPageFilterHost<_ArtistPage> {
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
    final artistKey = widget.artistKey;
    final sections = widget.sections;
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final songs = sections.songs;
    final coverDirectory = ref.watch(coverCacheDirectoryProvider);
    // Built when a track is tapped, not on every rebuild of a long page.
    List<player.Track> queueOf(List<BrowseTrack> list) => [
      for (final t in list)
        trackFromBrowse(t, artPath: coverPath(coverDirectory, t.coverKey)),
    ];
    void queueAlbum(AlbumTileData album, QueueAction action) =>
        enqueueAlbum(ref, context, action, album.key, album.title);
    void openAlbum(AlbumTileData album) =>
        context.go(artistAlbumLocation(artistKey, album.key));
    Widget heading(String text) => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
        child: Text(text, style: theme.textTheme.titleLarge),
      ),
    );
    // Play and Shuffle in the header always take every song.
    void onPlay() => playTracks(ref, queueOf(songs), 0);
    void onShuffle() => shuffleTracks(ref, queueOf(songs));
    void onQueueAction(QueueAction action) =>
        enqueueLoaded(ref, context, action, queueOf(songs), sections.name);

    return CoverTintPageBackground(
      coverKey: sections.coverKey,
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
                      child: ArtistHeader(
                        artistKey: artistKey,
                        name: sections.name,
                        albumCount: sections.albumCount,
                        onPlay: onPlay,
                        onShuffle: onShuffle,
                        onQueueAction: onQueueAction,
                      ),
                    ),
                  if (!filtering && sections.albums.isNotEmpty) ...[
                    heading(l10n.artistsAlbums),
                    SliverAlbumRow(
                      albums: sections.albums,
                      onTap: openAlbum,
                      onQueueAction: queueAlbum,
                    ),
                  ],
                  if (!filtering && sections.appearsOn.isNotEmpty) ...[
                    heading(l10n.artistsAppearsOn),
                    SliverAlbumRow(
                      albums: sections.appearsOn,
                      onTap: openAlbum,
                      onQueueAction: queueAlbum,
                    ),
                  ],
                  SliverTracksToolbar(
                    songCount: songs.length,
                    durationMs: sections.durationMs,
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
              ArtistSidePane(
                artistKey: artistKey,
                name: sections.name,
                coverKey: sections.coverKey,
                albumCount: sections.albumCount,
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

class _ArtistNotFound extends StatelessWidget {
  const _ArtistNotFound();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageScaffold(
      title: l10n.navArtists,
      body: EmptyState(
        icon: AppIcons.artistOutline,
        title: l10n.artistsNotFound,
        message: l10n.artistsNotFoundMessage,
      ),
    );
  }
}
