import 'package:material_ui/material_ui.dart';

import '../../../core/player/track.dart';
import '../track_artwork.dart';

/// Large cover, title and artist, centered. The album is not shown: tracks
/// carry no album yet.
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
        Center(
          child: TrackArtwork(
            artUri: track.artUri,
            size: artworkSize,
            radius: 32,
          ),
        ),
        NowPlayingTitle(track: track),
      ],
    );
  }
}

/// Title (bold, up to two lines) and artist, as under the large cover.
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
      spacing: 8,
      children: [
        trailing == null
            ? title
            : Row(
                children: [
                  Expanded(child: title),
                  trailing!,
                ],
              ),
        if (artist != null)
          Opacity(
            opacity: 0.7,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                const Icon(Icons.person_rounded, size: 20),
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
    );
  }
}

/// Title (bold) and artist, small and centered: what stays on top of the
/// lyrics in the lyrics-only view. The album joins once tracks carry one.
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
