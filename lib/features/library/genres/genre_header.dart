import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../play_shuffle_actions.dart';
import 'genre_avatar.dart';

/// Avatar, name, "N albums · N songs" and the Play, Shuffle and queue
/// buttons of a genre page.
class GenreHeader extends StatelessWidget {
  const GenreHeader({
    super.key,
    required this.genreKey,
    required this.name,
    required this.albumCount,
    required this.songCount,
    required this.onPlay,
    required this.onShuffle,
    required this.onQueueAction,
  });

  final String genreKey;
  final String name;
  final int albumCount;
  final int songCount;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final ValueChanged<QueueAction> onQueueAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
      child: Row(
        children: [
          GenreAvatar(genreKey: genreKey, size: 120),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.artistsAlbumCount(albumCount)} · '
                  '${l10n.albumsSongCount(songCount)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                PlayShuffleActions(
                  playLabel: l10n.albumsPlay,
                  onPlay: onPlay,
                  onShuffle: onShuffle,
                  onQueueAction: onQueueAction,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
