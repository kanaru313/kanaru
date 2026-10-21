import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/format_duration.dart';
import '../widgets/album_artwork.dart';
import '../widgets/queue_actions_menu.dart';

/// Artwork, title, artist, "year · N songs · duration" and a Play button.
class AlbumHeader extends StatelessWidget {
  const AlbumHeader({
    super.key,
    required this.albumKey,
    required this.album,
    required this.onPlay,
    required this.onQueueAction,
    this.artist,
  });

  final AlbumKey albumKey;
  final AlbumSummary album;
  final VoidCallback onPlay;
  final ValueChanged<QueueAction> onQueueAction;

  /// Replaces the plain artist name, for example with a link.
  final Widget? artist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final durationMs = album.durationMs;
    final details = [
      if (album.year != null) '${album.year}',
      l10n.albumsSongCount(album.trackCount),
      if (durationMs != null)
        formatDuration(Duration(milliseconds: durationMs)),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AlbumArtwork(albumKey: albumKey, coverKey: album.coverKey, size: 160),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  album.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                artist ??
                    Text(
                      album.artist ?? l10n.albumsUnknownArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      onPressed: onPlay,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l10n.albumsPlay),
                    ),
                    const SizedBox(width: 4),
                    QueueActionsButton(onSelected: onQueueAction),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
