import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart' show TrackListItem;
import '../../core/database/library_startup.dart'
    show coverCacheDirectoryProvider;
import '../../core/player/track.dart';
import '../../l10n/l10n.dart';
import '../../shared/artist_page/enqueue_artist.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/library_route_keys.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/album_list_tile.dart';
import '../../shared/widgets/artist_tile.dart';
import '../../shared/widgets/song_tile.dart';

import 'search_corrected_banner.dart';
import 'search_providers.dart';
import 'search_section.dart';

/// The songs, albums and artists [results] found, as one scrolling page.
/// "Show all" opens a group in place ("Show less" closes it); give the widget a new key per query so
/// the groups close again.
class SearchResultsView extends ConsumerStatefulWidget {
  const SearchResultsView({
    super.key,
    required this.results,
    required this.onOpened,
    this.correctedQuery,
  });

  final SearchResults results;

  /// The query with its misspelt words fixed, when part of [results] comes
  /// from it; shown above the groups.
  final String? correctedQuery;

  /// Called when the user opens a result (plays or queues a song, opens an
  /// album or artist): the moment the query is worth remembering.
  final VoidCallback onOpened;

  @override
  ConsumerState<SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends ConsumerState<SearchResultsView> {
  bool _songs = false;
  bool _albums = false;
  bool _artists = false;

  /// Remembers the query: a result was played, queued or opened. Some calls
  /// come from a modal's footer after the modal has closed, so it checks that
  /// this State is still mounted.
  void _recordQuery() {
    if (mounted) widget.onOpened();
  }

  /// The queue entry for [song], with its cover.
  Track _track(TrackListItem song) =>
      trackFromListItem(song, ref.read(coverCacheDirectoryProvider));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final r = widget.results;
    return CustomScrollView(
      slivers: [
        if (widget.correctedQuery case final corrected?)
          SliverToBoxAdapter(child: SearchCorrectedBanner(query: corrected)),
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
              onTap: () {
                _recordQuery();
                playTracks(ref, [_track(song)], 0);
              },
              onQueueAction: (action) {
                _recordQuery();
                enqueueLoaded(ref, context, action, [_track(song)], song.title);
              },
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
              onTap: () {
                _recordQuery();
                context.go(albumLocation(album.key));
              },
              onPlay: () {
                _recordQuery();
                unawaited(playAlbum(ref, album.key));
              },
              // This State stays mounted under the modal, so its ref and
              // context are live when the action is picked.
              onQueueAction: (action) {
                _recordQuery();
                enqueueAlbum(ref, context, action, album.key, album.title);
              },
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
              onTap: () {
                _recordQuery();
                context.go(artistLocation(artist.key));
              },
              onPlay: () {
                _recordQuery();
                unawaited(playArtist(ref, artist.key));
              },
              onQueueAction: (action) {
                _recordQuery();
                enqueueArtist(ref, context, action, artist.key, artist.name);
              },
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
