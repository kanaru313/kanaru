import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/library_route_keys.dart' show unknownGenreKey;
import '../../../shared/widgets/playlist_cover.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../play_shuffle_actions.dart';
import '../widgets/detail_side_pane.dart';

/// Header of a genre page in a narrow window: cover collage beside the name,
/// "N albums · N songs" and the Play, Shuffle and queue buttons. A wide
/// window shows [GenreSidePane] instead.
class GenreHeader extends StatelessWidget {
  const GenreHeader({
    super.key,
    required this.genreKey,
    required this.name,
    required this.albumCount,
    required this.songCount,
    required this.coverKeys,
    required this.onPlay,
    required this.onShuffle,
    required this.onQueueAction,
  });

  final String genreKey;
  final String name;
  final int albumCount;
  final int songCount;
  final List<String> coverKeys;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final ValueChanged<QueueAction> onQueueAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
      child: Row(
        children: [
          PlaylistCover(
            coverKeys: coverKeys,
            size: 120,
            seed: 'genre:$genreKey',
            icon: _genreIcon(genreKey),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: _GenreDetails(
              name: name,
              albumCount: albumCount,
              songCount: songCount,
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

/// Left column of a genre page in a wide window: the cover collage edge to
/// edge, fading into the page at its foot, then the name, counts and the
/// Play buttons at its right end (see [DetailSidePane]).
class GenreSidePane extends StatelessWidget {
  const GenreSidePane({
    super.key,
    required this.genreKey,
    required this.name,
    required this.albumCount,
    required this.songCount,
    required this.coverKeys,
    required this.onPlay,
    required this.onShuffle,
    required this.onQueueAction,
  });

  final String genreKey;
  final String name;
  final int albumCount;
  final int songCount;
  final List<String> coverKeys;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final ValueChanged<QueueAction> onQueueAction;

  @override
  Widget build(BuildContext context) {
    return DetailSidePane(
      cover: PlaylistCover(
        coverKeys: coverKeys,
        size: detailSidePaneWidth,
        radius: 0,
        seed: 'genre:$genreKey',
        icon: _genreIcon(genreKey),
      ),
      details: _GenreDetails(
        name: name,
        albumCount: albumCount,
        songCount: songCount,
        titleStyle: Theme.of(context).textTheme.headlineSmall,
        actionsAtEnd: true,
        onPlay: onPlay,
        onShuffle: onShuffle,
        onQueueAction: onQueueAction,
      ),
    );
  }
}

IconData _genreIcon(String genreKey) =>
    genreKey == unknownGenreKey ? AppIcons.genreOutlined : AppIcons.genre;

/// Name (bold, two lines at most), "N albums · N songs" and the Play
/// buttons, at the right end of the column when [actionsAtEnd] is on.
class _GenreDetails extends StatelessWidget {
  const _GenreDetails({
    required this.name,
    required this.albumCount,
    required this.songCount,
    required this.titleStyle,
    this.actionsAtEnd = false,
    required this.onPlay,
    required this.onShuffle,
    required this.onQueueAction,
  });

  final String name;
  final int albumCount;
  final int songCount;
  final TextStyle? titleStyle;
  final bool actionsAtEnd;
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
          '${l10n.artistsAlbumCount(albumCount)} · '
          '${l10n.albumsSongCount(songCount)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: actionsAtEnd
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: PlayShuffleActions(
            playLabel: l10n.albumsPlay,
            onPlay: onPlay,
            onShuffle: onShuffle,
            onQueueAction: onQueueAction,
          ),
        ),
      ],
    );
  }
}
