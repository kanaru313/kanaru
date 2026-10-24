import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/genre_summaries.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/library_route_keys.dart' show unknownGenreKey;
import '../../../shared/widgets/playlist_cover.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../albums/album_grid_tile.dart';
import '../widgets/round_grid_tile.dart';
import 'genre_display_name.dart';

/// One genre in a grid: cover collage, name, "N songs".
class GenreGridTile extends StatelessWidget {
  const GenreGridTile({
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
  Widget build(BuildContext context) => RoundGridTile(
    avatarBuilder: (size) => PlaylistCover(
      coverKeys: genre.coverKeys,
      size: size,
      seed: 'genre:${genre.key}',
      icon: genre.key == unknownGenreKey
          ? AppIcons.genreOutlined
          : AppIcons.genre,
    ),
    title: genreDisplayName(context.l10n, genre.key, genre.name),
    subtitle: context.l10n.albumsSongCount(genre.songCount),
    onTap: onTap,
    onQueueAction: onQueueAction,
  );
}

/// [genres] as a scrolling grid.
class GenreGrid extends StatelessWidget {
  const GenreGrid({
    super.key,
    required this.genres,
    required this.onTap,
    this.onQueueAction,
  });

  final List<GenreSummary> genres;
  final void Function(GenreSummary genre) onTap;

  /// An action picked from the menu of [genre]; no menus without it.
  final void Function(GenreSummary genre, QueueAction action)? onQueueAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          albumGridPadding,
          0,
          albumGridPadding,
          24,
        ),
        gridDelegate: libraryGridDelegate(
          context,
          constraints.maxWidth - albumGridPadding * 2,
          tileHeight: roundGridTileHeight,
        ),
        itemCount: genres.length,
        itemBuilder: (context, i) => GenreGridTile(
          genre: genres[i],
          onTap: () => onTap(genres[i]),
          onQueueAction: onQueueAction == null
              ? null
              : (action) => onQueueAction!(genres[i], action),
        ),
      ),
    );
  }
}
