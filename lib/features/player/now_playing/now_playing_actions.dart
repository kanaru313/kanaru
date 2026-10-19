import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../playback_controls.dart';

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

/// Add to playlist. Playlists do not exist yet: the button only says so.
class NowPlayingPlaylistButton extends StatelessWidget {
  const NowPlayingPlaylistButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.playlist_add_rounded),
    iconSize: playerIconSize,
    tooltip: context.l10n.nowPlayingAddToPlaylist,
    onPressed: () => _comingSoon(context),
  );
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
