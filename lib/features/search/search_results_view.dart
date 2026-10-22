import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart' show TrackListItem;
import '../../core/indexer/cover_paths.dart';
import '../../core/database/library_startup.dart'
    show coverCacheDirectoryProvider;
import '../../core/player/track.dart';
import '../../l10n/l10n.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/library_route_keys.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/album_list_tile.dart';
import '../../shared/widgets/artist_tile.dart';
import '../../shared/widgets/song_tile.dart';

import 'search_providers.dart';
import 'search_section.dart';

/// The songs, albums and artists [results] found, as one scrolling page.
/// "Show all" opens a group in place ("Show less" closes it); give the widget a new key per query so
/// the groups close again.
class SearchResultsView extends ConsumerStatefulWidget {
  const SearchResultsView({super.key, required this.results});

  final SearchResults results;

  @override
  ConsumerState<SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends ConsumerState<SearchResultsView> {
  bool _songs = false;
  bool _albums = false;
  bool _artists = false;

  /// The queue entry for [song], with its cover.
  Track _track(TrackListItem song) => trackFromItem(
    path: song.path,
    title: song.title,
    artist: song.artist,
    durationMs: song.durationMs,
    artPath: coverPath(ref.read(coverCacheDirectoryProvider), song.coverKey),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final r = widget.results;
    return CustomScrollView(
      slivers: [
        if (r.songs.isNotEmpty)
          ...searchSectionSlivers<TrackListItem>(
            context: context,
            title: l10n.navSongs,
            count: r.songTotal,
            items: r.songs,
            expanded: _songs,
            onToggle: () => setState(() => _songs = !_songs),
            rowBuilder: (song) => SongTile(
              song: song,
              // Plays only this song: a search result has no list context.
              onTap: () => playTracks(ref, [_track(song)], 0),
              onQueueAction: (action) => enqueueLoaded(ref, context, action, [
                _track(song),
              ], song.title),
            ),
            footer: _songs && r.songTotal > r.songs.length
                ? _Hint(l10n.searchMoreSongs(r.songs.length, r.songTotal))
                : null,
          ),
        if (r.albums.isNotEmpty)
          ...searchSectionSlivers(
            context: context,
            title: l10n.navAlbums,
            count: r.albums.length,
            items: r.albums,
            expanded: _albums,
            onToggle: () => setState(() => _albums = !_albums),
            rowBuilder: (album) => AlbumListTile(
              album: album,
              onTap: () => context.go(albumLocation(album.key)),
            ),
          ),
        if (r.artists.isNotEmpty)
          ...searchSectionSlivers(
            context: context,
            title: l10n.navArtists,
            count: r.artists.length,
            items: r.artists,
            expanded: _artists,
            onToggle: () => setState(() => _artists = !_artists),
            rowBuilder: (artist) => ArtistTile(
              artist: artist,
              onTap: () => context.go(artistLocation(artist.key)),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
