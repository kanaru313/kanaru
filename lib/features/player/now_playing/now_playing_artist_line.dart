import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_browse_now_playing.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/playing_track_art.dart' show localPathOf;
import '../../../shared/icons/app_icons.dart';
import '../../../shared/library_route_keys.dart';
import '../../../shared/track_menu_actions.dart' show showArtistPicker;
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

/// The artist line under the playing song's title. Taps close Now Playing
/// and open the artist page; a song credited to several artists asks which
/// one first, as the song menu does. Without a router or a library match it
/// is plain text. Shows [artist] (the tag, as the title's style already did)
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
  Offset _tapPosition = Offset.zero;

  Future<void> _open(
    GoRouter router,
    List<({String key, String name})> artists,
  ) async {
    if (artists.isEmpty) return;
    if (artists.length == 1) {
      ref.read(nowPlayingOpenProvider.notifier).close();
      router.go(artistLocation(artists.single.key));
      return;
    }
    final key = await showArtistPicker(context, _tapPosition, artists);
    if (key == null || !context.mounted) return;
    ref.read(nowPlayingOpenProvider.notifier).close();
    router.go(artistLocation(key));
  }

  @override
  Widget build(BuildContext context) {
    final artists = ref.watch(nowPlayingArtistsProvider).value ?? const [];
    final router = GoRouter.maybeOf(context);
    final line = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        const Icon(AppIcons.artistRounded, size: 20),
        Flexible(
          child: Text(
            widget.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
    if (router == null || artists.isEmpty) {
      return Opacity(opacity: 0.7, child: line);
    }
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTapDown: (details) => _tapPosition = details.globalPosition,
      onTap: () => _open(router, artists),
      child: Opacity(opacity: 0.7, child: line),
    );
  }
}
