import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/player_service.dart';
import '../../l10n/l10n.dart';
import 'now_playing/now_playing_open_cover.dart';
import 'open_media.dart';

/// Left side of the player bar: cover, title and artist of the current
/// track, or progress while a folder is being scanned.
class NowPlayingSummary extends ConsumerWidget {
  const NowPlayingSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final track = ref.watch(
      playerServiceProvider.select((s) => s.queue.current),
    );
    final scanning = ref.watch(openMediaProvider);

    if (scanning) {
      return Row(
        spacing: 12,
        children: [
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          Flexible(
            child: Text(l10n.playerScanning, overflow: TextOverflow.ellipsis),
          ),
        ],
      );
    }

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
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: NowPlayingOpenCover(
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: SizedBox.square(
                dimension: 64,
                child: Icon(
                  Icons.music_note_rounded,
                  size: 32,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
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
