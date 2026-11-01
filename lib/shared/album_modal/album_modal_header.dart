import 'package:material_ui/material_ui.dart';

import '../../core/database/library_browse_rows.dart';
import '../../l10n/l10n.dart';
import '../album_artist_label.dart';
import '../icons/app_icons.dart';
import '../widgets/album_artwork.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/library_grid/album_tile_data.dart';
import '../widgets/library_row.dart';

const double _coverSize = 64;

/// Top of the album modal: the cover, then the artist line, the title and
/// "year • N songs • length", and the Edit album art button (not available
/// yet). [summary] is null until the album is read; the year shows at once.
/// The header itself is not tappable.
class AlbumModalHeader extends StatelessWidget {
  const AlbumModalHeader({super.key, required this.album, this.summary});

  final AlbumTileData album;
  final AlbumSummary? summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final quiet = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final duration = summary?.durationMs;
    final details = joinRowDetails([
      rowYear(album.year),
      if (summary case final s?) l10n.albumsSongCount(s.trackCount),
      if (duration != null) l10n.albumsMinutes(rowMinutes(duration)),
    ]);
    Widget line(String text, TextStyle? style) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 10, 12),
      child: Row(
        spacing: 16,
        children: [
          AlbumArtwork(
            albumKey: album.key,
            coverKey: album.coverKey,
            size: _coverSize,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                line(
                  albumArtistLabel(
                    l10n,
                    artist: album.artist,
                    variousArtists: album.variousArtists,
                  ),
                  quiet,
                ),
                line(album.title, theme.textTheme.titleMedium),
                if (details.isNotEmpty) line(details, quiet),
              ],
            ),
          ),
          // Coming soon: no keyboard focus, like the coming-soon rows; the
          // hint reaches the button's own semantics node.
          MergeSemantics(
            child: Semantics(
              hint: l10n.contextModalComingSoon,
              child: ExcludeFocus(
                child: IconButton(
                  tooltip: l10n.albumModalEditAlbumArt,
                  icon: const Icon(AppIcons.editAlbumArt),
                  color: colors.onSurfaceVariant.withValues(alpha: 0.38),
                  onPressed: () => ScaffoldMessenger.maybeOf(context)
                      ?.showSnackBar(
                        appSnackBar(
                          kind: AppSnackBarKind.info,
                          title: l10n.contextModalComingSoonSnack,
                        ),
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
