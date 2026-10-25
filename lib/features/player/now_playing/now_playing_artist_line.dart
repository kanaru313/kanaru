import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_browse_now_playing.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/playing_track_art.dart' show localPathOf;
import '../../../shared/library_route_keys.dart';
import '../../../shared/widgets/hover_underline_links.dart';
import '../../../shared/track_menu_actions.dart' show showArtistPicker;
import 'now_playing_artist_segments.dart';
import 'now_playing_open_provider.dart';

final _log = Logger('now_playing');

/// The playing library file's credited artists (tag order); empty when
/// nothing plays, the file is not in the library or it has no artist tag.
/// While the next song's artists are looked up the previous value stays, so
/// the line does not blink between songs of one artist; a failed lookup
/// gives an empty list, never the old one.
final nowPlayingArtistsProvider =
    FutureProvider.autoDispose<List<({String key, String name})>>((ref) async {
      final uri = ref.watch(
        playerServiceProvider.select((s) => s.queue.current?.uri),
      );
      final path = uri == null ? null : localPathOf(uri);
      if (path == null) return const [];
      try {
        return await ref.watch(libraryDatabaseProvider)?.artistsOfPath(path) ??
            const [];
      } on Object catch (error, stack) {
        // An error state would keep the previous song's artists on screen.
        _log.warning('Reading the artists of $path failed', error, stack);
        return const [];
      }
    });

/// The artist line under the playing song's title. Each credited name is a
/// link: a tap closes Now Playing and opens that artist's page. When the
/// names cannot be found in the tag, the whole tag is one link and a song
/// credited to several artists asks which one first, as the song menu does.
/// Without a router or a library match it is plain text. Shows [artist] (the tag, as the title's style already did)
/// whether or not a link was found, so a song outside the library still
/// names its artist.
class NowPlayingArtistLine extends ConsumerStatefulWidget {
  const NowPlayingArtistLine({super.key, required this.artist});

  final String artist;

  @override
  ConsumerState<NowPlayingArtistLine> createState() =>
      _NowPlayingArtistLineState();
}

class _NowPlayingArtistLineState extends ConsumerState<NowPlayingArtistLine> {
  void _go(GoRouter router, String key) {
    ref.read(nowPlayingOpenProvider.notifier).close();
    router.go(artistLocation(key));
  }

  Future<void> _pick(
    GoRouter router,
    List<({String key, String name})> artists,
    Offset position,
  ) async {
    final key = await showArtistPicker(context, position, artists);
    if (key == null || !context.mounted) return;
    _go(router, key);
  }

  @override
  Widget build(BuildContext context) {
    final artists = ref.watch(nowPlayingArtistsProvider).value ?? const [];
    final router = GoRouter.maybeOf(context);
    final style = Theme.of(context).textTheme.bodyLarge;
    if (router == null || artists.isEmpty) {
      return Opacity(
        opacity: 0.7,
        child: Text(
          widget.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      );
    }
    final segments = artistLineSegments(widget.artist, [
      for (final a in artists) a.name,
    ]);
    // Names found in the tag link one artist each; the whole tag as the only
    // link stands for all of them.
    final wholeTag = artists.length > 1 && segments.length == 1;
    return Opacity(
      opacity: 0.7,
      child: HoverUnderlineLinks(
        style: style,
        // One Tab stop for the line: the keyboard asks which artist.
        onActivate: artists.length > 1
            ? (position) => _pick(router, artists, position)
            : null,
        segments: [
          for (final s in segments)
            LinkSegment(
              s.text,
              onTap: switch (s.artist) {
                null => null,
                _ when wholeTag => (position) => _pick(
                  router,
                  artists,
                  position,
                ),
                final i => (_) => _go(router, artists[i].key),
              },
            ),
        ],
      ),
    );
  }
}
