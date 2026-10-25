import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'now_playing_album_line.dart';
import 'now_playing_artist_line.dart';

/// "Artist · album" on one centered line, for Cover only. Both parts keep
/// their links and shrink with an ellipsis; the dot shows only when both
/// exist, so a song without album (or without artist) reads as one part.
class NowPlayingArtistAlbumLine extends ConsumerWidget {
  const NowPlayingArtistAlbumLine({super.key, required this.artist});

  /// The artist tag of the playing song; `null` when it has none.
  final String? artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAlbum = ref.watch(nowPlayingAlbumProvider).value != null;
    final artist = this.artist;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (artist != null)
          Flexible(
            child: NowPlayingArtistLine(artist: artist, showIcon: false),
          ),
        if (artist != null && hasAlbum)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Opacity(
              opacity: 0.7,
              child: Text('·', style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
        const Flexible(
          child: NowPlayingAlbumLine(
            centered: true,
            padded: false,
            showIcon: false,
          ),
        ),
      ],
    );
  }
}
