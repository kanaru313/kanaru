import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/indexer/cover_paths.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/artist_avatar.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/placeholder_colors.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../play_shuffle_actions.dart';
import '../widgets/detail_side_pane.dart';

/// Header of an artist page in a narrow window: avatar beside the name,
/// "N albums" and the Play buttons. The song count and length sit in the
/// bar over the songs. A wide window shows [ArtistSidePane] instead.
class ArtistHeader extends StatelessWidget {
  const ArtistHeader({
    super.key,
    required this.artistKey,
    required this.name,
    required this.albumCount,
    required this.onPlay,
    required this.onShuffle,
    required this.onQueueAction,
  });

  final String artistKey;
  final String name;
  final int albumCount;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final ValueChanged<QueueAction> onQueueAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
      child: Row(
        children: [
          ArtistAvatar(artistKey: artistKey, name: name, size: 120),
          const SizedBox(width: 24),
          Expanded(
            child: _ArtistDetails(
              name: name,
              albumCount: albumCount,
              titleStyle: Theme.of(context).textTheme.headlineMedium,
              onPlay: onPlay,
              onShuffle: onShuffle,
              onQueueAction: onQueueAction,
            ),
          ),
        ],
      ),
    );
  }
}

/// Left column of an artist page in a wide window: the cover of the
/// artist's first album with one ([coverKey]; else the first letter of the
/// name on a color picked from [artistKey]), then the name, "N albums" and
/// the Play buttons (see [DetailSidePane]).
class ArtistSidePane extends ConsumerWidget {
  const ArtistSidePane({
    super.key,
    required this.artistKey,
    required this.name,
    required this.coverKey,
    required this.albumCount,
    required this.onPlay,
    required this.onShuffle,
    required this.onQueueAction,
  });

  final String artistKey;
  final String name;
  final String? coverKey;
  final int albumCount;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final ValueChanged<QueueAction> onQueueAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (background, foreground) = placeholderColors(
      theme.colorScheme,
      artistKey,
    );
    return DetailSidePane(
      cover: CoverArt(
        path: coverPath(ref.watch(coverCacheDirectoryProvider), coverKey),
        size: detailSidePaneWidth,
        radius: 0,
        placeholder: ColoredBox(
          color: background,
          child: Center(
            child: Text(
              name.characters.firstOrNull?.toUpperCase() ?? '',
              style: TextStyle(
                fontSize: detailSidePaneWidth * 0.4,
                color: foreground,
              ),
              textScaler: TextScaler.noScaling,
            ),
          ),
        ),
      ),
      details: _ArtistDetails(
        name: name,
        albumCount: albumCount,
        titleStyle: theme.textTheme.headlineSmall,
        onPlay: onPlay,
        onShuffle: onShuffle,
        onQueueAction: onQueueAction,
      ),
    );
  }
}

/// Name (bold, two lines at most), "N albums" and the Play buttons.
class _ArtistDetails extends StatelessWidget {
  const _ArtistDetails({
    required this.name,
    required this.albumCount,
    required this.titleStyle,
    required this.onPlay,
    required this.onShuffle,
    required this.onQueueAction,
  });

  final String name;
  final int albumCount;
  final TextStyle? titleStyle;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final ValueChanged<QueueAction> onQueueAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.artistsAlbumCount(albumCount),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        PlayShuffleActions(
          playLabel: l10n.artistsPlay,
          onPlay: onPlay,
          onShuffle: onShuffle,
          onQueueAction: onQueueAction,
        ),
      ],
    );
  }
}
