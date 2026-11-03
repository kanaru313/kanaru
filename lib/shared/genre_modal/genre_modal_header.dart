import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../genre_summaries.dart';
import '../icons/app_icons.dart';
import '../library_route_keys.dart' show unknownGenreKey;
import '../widgets/library_row.dart';
import '../widgets/playlist_cover.dart';

const double _coverSize = 64;

/// Top of the genre modal: the cover collage, the name and
/// "N albums • N songs • length". The song count comes from the tile the
/// modal was opened from, so it shows at once; the album count and duration
/// appear once the links load.
///
/// With [onTap] (Go to genre, which closes the modal first) the cover and
/// the text are one button that does not take keyboard focus: the first row
/// does. It is null on the page of the genre itself.
class GenreModalHeader extends StatelessWidget {
  const GenreModalHeader({
    super.key,
    required this.genre,
    required this.displayName,
    this.albumCount,
    this.durationMs,
    this.onTap,
  });

  final GenreSummary genre;
  final String displayName;
  final int? albumCount;
  final int? durationMs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final quiet = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final albums = albumCount;
    final duration = durationMs;
    final details = joinRowDetails([
      if (albums != null) l10n.artistsAlbumCount(albums),
      l10n.albumsSongCount(genre.songCount),
      if (duration != null) rowLength(l10n, duration),
    ]);
    Widget line(String text, TextStyle? style) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    final identity = Row(
      spacing: 16,
      children: [
        PlaylistCover(
          coverKeys: genre.coverKeys,
          size: _coverSize,
          seed: 'genre:${genre.key}',
          icon: genre.key == unknownGenreKey
              ? AppIcons.genreOutlined
              : AppIcons.genre,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              line(displayName, theme.textTheme.titleMedium),
              line(details, quiet),
            ],
          ),
        ),
      ],
    );
    final tap = onTap;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: tap == null
          ? identity
          : Semantics(
              button: true,
              hint: l10n.songModalGoToGenre,
              child: InkWell(
                canRequestFocus: false,
                borderRadius: BorderRadius.circular(12),
                onTap: tap,
                child: identity,
              ),
            ),
    );
  }
}
