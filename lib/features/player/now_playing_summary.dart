import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/player_service.dart';
import 'now_playing/now_playing_open_cover.dart';
import 'track_artwork.dart';

/// Left side of the player bar: cover, title and artist of the current
/// track.
class NowPlayingSummary extends ConsumerWidget {
  const NowPlayingSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final track = ref.watch(
      playerServiceProvider.select((s) => s.queue.current),
    );

    if (track == null) return const SizedBox.shrink();

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
    );
    final artistStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Row(
      spacing: 12,
      children: [
        NowPlayingOpenCover(child: const PlayingTrackArtwork(size: 64)),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
              if (track.artist case final artist?)
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: artistStyle,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
