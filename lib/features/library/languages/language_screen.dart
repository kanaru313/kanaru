import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/player/track.dart' as player;
import '../../../l10n/l10n.dart';
import '../../../shared/enqueue_tracks.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/language_display_name.dart';
import '../../../shared/library_route_keys.dart';
import '../../../shared/play_tracks.dart';
import '../../../shared/widgets/not_found_page.dart';
import '../../../shared/widgets/song_tile.dart';
import '../library_detail_body.dart';
import 'language_header.dart';
import 'language_page_data.dart';
import '../../../shared/widgets/library_grid/album_tile_data.dart';
import '../albums/album_grid.dart';

/// One language: header, then its albums and its songs. Tapping a song plays
/// the songs from it. [routeKey] comes from the URL; a broken key or a
/// language without tracks shows "not found".
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key, required this.routeKey});

  final String routeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageKey = decodeLanguageRouteKey(routeKey);
    return LibraryDetailBody<LanguagePageData>(
      page: languageKey == null ? null : languagePageProvider(languageKey),
      what: 'the language',
      notFound: NotFoundPage(
        pageTitle: context.l10n.navLanguages,
        icon: AppIcons.language,
        title: context.l10n.languagesNotFound,
        message: context.l10n.languagesNotFoundMessage,
      ),
      builder: (data) => _LanguagePage(languageKey: languageKey!, data: data),
    );
  }
}

class _LanguagePage extends ConsumerWidget {
  const _LanguagePage({required this.languageKey, required this.data});

  final String languageKey;
  final LanguagePageData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final songs = data.tracks;
    final name = languageDisplayName(l10n, languageKey);
    final coverDirectory = ref.watch(coverCacheDirectoryProvider);
    // Built when a track is tapped, not on every rebuild of a long page.
    List<player.Track> queue() => [
      for (final t in songs) trackFromRow(t, coverDirectory),
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
          child: LanguageHeader(
            languageKey: languageKey,
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
          heading(l10n.languagesAlbums),
          SliverAlbumGrid(
            albums: data.albums,
            onTap: (AlbumTileData album) =>
                context.go(albumLocation(album.key)),
            onQueueAction: (album, action) =>
                enqueueAlbum(ref, context, action, album.key, album.title),
          ),
        ],
        heading(l10n.languagesSongs),
        SliverList.builder(
          itemCount: songs.length,
          itemBuilder: (context, i) => SongTile(
            song: songs[i],
            onTap: () => playTracks(ref, queue(), i),
            onQueueAction: (action) => enqueueLoaded(ref, context, action, [
              trackFromRow(songs[i], coverDirectory),
            ], songs[i].title),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}
