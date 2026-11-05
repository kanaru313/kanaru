import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/genre_modal/genre_actions_region.dart';
import '../../../shared/genre_modal/genre_more_button.dart';
import '../../../shared/genre_summaries.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/library_route_keys.dart' show unknownGenreKey;
import '../../../shared/widgets/library_row.dart';
import '../../../shared/widgets/playlist_cover.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../../../shared/widgets/song_card.dart';
import 'enqueue_genre.dart';
import 'genre_display_name.dart';

/// One genre row: cover collage, name, "N songs • M min", and "Genre".
class GenreTile extends ConsumerWidget {
  const GenreTile({
    super.key,
    required this.genre,
    required this.onTap,
    this.onQueueAction,
  });

  final GenreSummary genre;
  final VoidCallback onTap;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final durationMs = genre.durationMs;
    final tile = LibraryPlayableRow(
      leading: PlaylistCover(
        coverKeys: genre.coverKeys,
        size: libraryRowCoverSize,
        seed: 'genre:${genre.key}',
        icon: genre.key == unknownGenreKey
            ? AppIcons.genreOutlined
            : AppIcons.genre,
      ),
      lines: [
        genreDisplayName(l10n, genre.key, genre.name),
        joinRowDetails([
          l10n.albumsSongCount(genre.songCount),
          if (durationMs != null && durationMs > 0) rowLength(l10n, durationMs),
        ]),
        l10n.searchFieldGenre,
      ],
      onTap: onTap,
      onPlay: () => unawaited(playGenre(ref, genre)),
      playTooltip: l10n.albumsPlay,
      more: onQueueAction == null
          ? null
          : GenreMoreButton(genre: genre, onQueueAction: onQueueAction!),
      horizontalPadding: songCardInset,
      inkBorder: songCardShape,
    );
    return GenreActionsRegion(
      genre: genre,
      onQueueAction: onQueueAction,
      child: SongCardFrame(child: tile),
    );
  }
}
