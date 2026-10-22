import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/database/track_cover_lookup.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/playing_track_art.dart' show localPathOf;
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/add_to_playlist/add_to_playlist_flow.dart';
import '../playback_controls.dart';

final _log = Logger('playlists');

void _comingSoon(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(context.l10n.nowPlayingComingSoon)));
}

/// Heart. Favorites do not exist yet: the button only says so.
class NowPlayingFavoriteButton extends StatelessWidget {
  const NowPlayingFavoriteButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.favorite_border_rounded),
    iconSize: playerIconSize,
    tooltip: context.l10n.nowPlayingFavorite,
    onPressed: () => _comingSoon(context),
  );
}

/// Add to playlist: opens the playlist picker for the current track. Only a
/// song that is a row of the library can go in a playlist (the entries are
/// matched to library rows by path); any other says so.
class NowPlayingPlaylistButton extends ConsumerStatefulWidget {
  const NowPlayingPlaylistButton({super.key});

  @override
  ConsumerState<NowPlayingPlaylistButton> createState() =>
      _NowPlayingPlaylistButtonState();
}

class _NowPlayingPlaylistButtonState
    extends ConsumerState<NowPlayingPlaylistButton> {
  /// A pick is under way (the cover lookup or the picker is open): another
  /// press must not open a second picker.
  bool _busy = false;

  Future<void> _add(String path, String title) async {
    if (_busy) return;
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    _busy = true;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final inLibrary = await db.coverKeyOf(path) != null;
      if (!inLibrary) {
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text(l10n.playlistTrackNotInLibrary)),
          );
        return;
      }
      if (!mounted) return;
      await addTracksToPlaylist(ref, context, () async => [path], title);
    } catch (error, stack) {
      _log.severe('Adding the current song to a playlist failed', error, stack);
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.playlistSaveFailed)));
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(
      playerServiceProvider.select((s) => s.queue.current),
    );
    final path = track == null ? null : localPathOf(track.uri);
    final enabled = path != null && ref.watch(libraryDatabaseProvider) != null;
    return IconButton(
      icon: const Icon(Icons.playlist_add_rounded),
      iconSize: playerIconSize,
      tooltip: context.l10n.nowPlayingAddToPlaylist,
      onPressed: enabled ? () => _add(path, track!.title) : null,
    );
  }
}

/// Chevron that closes Now Playing.
class NowPlayingCloseButton extends StatelessWidget {
  const NowPlayingCloseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.expand_more_rounded),
    iconSize: playerIconSize,
    tooltip: context.l10n.nowPlayingClose,
    onPressed: onPressed,
  );
}
