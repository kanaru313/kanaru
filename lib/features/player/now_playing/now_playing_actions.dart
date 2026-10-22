import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/database/playlist_favorites.dart';
import '../../../core/database/playlist_providers.dart';
import '../../../core/database/track_cover_lookup.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/playing_track_art.dart' show localPathOf;
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/add_to_playlist/add_to_playlist_flow.dart';
import '../playback_controls.dart';

final _log = Logger('playlists');

void _say(ScaffoldMessengerState messenger, String text) => messenger
  ..clearSnackBars()
  ..showSnackBar(SnackBar(content: Text(text)));

/// The local path of the current song, or null (nothing playing, or a song
/// that is not a local file).
String? _currentPath(WidgetRef ref) {
  final track = ref.watch(playerServiceProvider.select((s) => s.queue.current));
  return track == null ? null : localPathOf(track.uri);
}

/// Heart: puts the current song in Favorites or takes it out. Only a song
/// that is a row of the library can be added (the playlist matches entries
/// to library rows by path); any song can be taken out, so one that left the
/// library is not stuck in Favorites.
///
/// The heart shows the wanted state at once. Presses while a write runs only
/// change the wanted state, and the writes run one after another, so two
/// quick presses end where they started.
class NowPlayingFavoriteButton extends ConsumerStatefulWidget {
  const NowPlayingFavoriteButton({super.key});

  @override
  ConsumerState<NowPlayingFavoriteButton> createState() =>
      _NowPlayingFavoriteButtonState();
}

class _NowPlayingFavoriteButtonState
    extends ConsumerState<NowPlayingFavoriteButton> {
  /// The state the user asked for and the song it is for, shown instead of
  /// the stored one until the stored one agrees.
  String? _wantedPath;
  bool? _wanted;
  bool _writing = false;

  Future<void> _press(String path, bool shown) async {
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    setState(() {
      _wantedPath = path;
      _wanted = !shown;
    });
    if (_writing) return;
    _writing = true;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      while (true) {
        final target = _wantedPath;
        final favorite = _wanted;
        if (target == null || favorite == null) break;
        try {
          if (favorite && await db.coverKeyOf(target) == null) {
            _say(messenger, l10n.playlistTrackNotInLibrary);
            _forgetIfStill(target, favorite);
          } else {
            await db.setFavorite(
              target,
              favorite: favorite,
              now: DateTime.now().millisecondsSinceEpoch,
            );
          }
        } catch (error, stack) {
          _log.severe('Changing the favorite of a song failed', error, stack);
          _say(messenger, l10n.playlistSaveFailed);
          _forgetIfStill(target, favorite);
        }
        // Done unless the user pressed again meanwhile (maybe on another
        // song): then the newer wish is written next.
        if (_wantedPath == null ||
            (_wantedPath == target && _wanted == favorite)) {
          break;
        }
      }
    } finally {
      // Rebuild so build() can drop the wanted state if the store already
      // caught up while the write was running.
      if (mounted) setState(() => _writing = false);
      _writing = false;
    }
  }

  /// Drops the wanted state after a failed write, unless the user asked for
  /// something newer meanwhile.
  void _forgetIfStill(String path, bool favorite) {
    if (_wantedPath != path || _wanted != favorite) return;
    _wantedPath = null;
    _wanted = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final path = _currentPath(ref);
    // Until the favorites have loaded, a press could like a liked song again.
    final loaded = ref.watch(favoritePathsProvider.select((s) => s.hasValue));
    final enabled =
        path != null && loaded && ref.watch(libraryDatabaseProvider) != null;
    final stored =
        path != null &&
        ref.watch(
          favoritePathsProvider.select((s) => s.value?.contains(path) ?? false),
        );
    // Once the writes are done and the store caught up (or the song
    // changed), stop overriding it, so a change made elsewhere shows. The
    // output is the same, so no rebuild is needed.
    if (_wanted != null &&
        !_writing &&
        (_wantedPath != path || _wanted == stored)) {
      _wantedPath = null;
      _wanted = null;
    }
    final favorite = _wanted != null && _wantedPath == path ? _wanted! : stored;
    final l10n = context.l10n;
    return IconButton(
      isSelected: favorite,
      icon: const Icon(AppIcons.favoriteBorderRounded),
      selectedIcon: const Icon(AppIcons.favoriteRounded),
      iconSize: playerIconSize,
      tooltip: favorite ? l10n.favoritesRemove : l10n.nowPlayingFavorite,
      onPressed: enabled ? () => _press(path, favorite) : null,
    );
  }
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
        _say(messenger, l10n.playlistTrackNotInLibrary);
        return;
      }
      if (!mounted) return;
      await addTracksToPlaylist(ref, context, () async => [path], title);
    } catch (error, stack) {
      _log.severe('Adding the current song to a playlist failed', error, stack);
      _say(messenger, l10n.playlistSaveFailed);
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
      icon: const Icon(AppIcons.playlistAddRounded),
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
    icon: const Icon(AppIcons.expandMoreRounded),
    iconSize: playerIconSize,
    tooltip: context.l10n.nowPlayingClose,
    onPressed: onPressed,
  );
}
