import 'package:material_ui/material_ui.dart';

import '../../../core/player/track.dart';
import '../../../shared/icons/app_icons.dart';
import 'now_playing_album_line.dart';
import 'now_playing_artwork.dart';

/// Large cover of the playing track, then [track]'s title, artist and album,
/// centered.
class NowPlayingTrackInfo extends StatelessWidget {
  const NowPlayingTrackInfo({
    super.key,
    required this.track,
    required this.artworkSize,
  });

  final Track track;
  final double artworkSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 24,
      children: [
        Center(child: NowPlayingArtwork(size: artworkSize, radius: 32)),
        NowPlayingTitle(track: track),
      ],
    );
  }
}

/// Title (bold, up to two lines), artist and album, as under the large cover.
class NowPlayingTitle extends StatelessWidget {
  const NowPlayingTitle({
    super.key,
    required this.track,
    this.centered = true,
    this.trailing,
  });

  final Track track;

  /// Centers the text; otherwise it starts at the left.
  final bool centered;

  /// Placed at the end of the title line, e.g. action buttons.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artist = track.artist;
    final title = Text(
      track.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.bold,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.stretch,
      children: [
        trailing == null
            ? title
            : Row(
                children: [
                  Expanded(child: title),
                  trailing!,
                ],
              ),
        if (artist != null) ...[
          const SizedBox(height: 8),
          Opacity(
            opacity: 0.7,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                const Icon(AppIcons.artistRounded, size: 20),
                Flexible(
                  child: Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ],
        NowPlayingAlbumLine(centered: centered),
      ],
    );
  }
}

/// Title (bold) and artist, small and centered: what stays on top of the
/// lyrics in the lyrics-only view.
class NowPlayingCompactInfo extends StatelessWidget {
  const NowPlayingCompactInfo({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artist = track.artist;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (artist != null)
          Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
