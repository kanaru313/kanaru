import 'package:material_ui/material_ui.dart';

import '../../core/database/library_browse_rows.dart';
import '../../l10n/l10n.dart';
import '../album_artist_label.dart';
import '../icons/app_icons.dart';
import '../widgets/album_artwork.dart';
import '../widgets/context_modal/context_modal_coming_soon_button.dart';
import '../widgets/context_modal/context_modal_header.dart';
import '../widgets/library_grid/album_tile_data.dart';
import '../widgets/library_row.dart';

const double _coverSize = 64;

/// Top of the album modal: the cover, then the artist line, the title and
/// "year • N songs • length", and the Edit album art button (not available
/// yet). [summary] is null until the album is read; the year shows at once.
///
/// With [onTap] (Go to album, which closes the modal first) the whole header
/// is one button that does not take keyboard focus: the first row does.
/// It is null on the page of the album itself. The Edit album art button
/// keeps its own tap.
class AlbumModalHeader extends StatelessWidget {
  const AlbumModalHeader({
    super.key,
    required this.album,
    this.summary,
    this.onTap,
  });

  final AlbumTileData album;
  final AlbumSummary? summary;
  final VoidCallback? onTap;

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
    return ContextModalHeader(
      leading: AlbumArtwork(
        albumKey: album.key,
        coverKey: album.coverKey,
        size: _coverSize,
      ),
      lines: [
        contextModalHeaderLine(
          albumArtistLabel(
            l10n,
            artist: album.artist,
            variousArtists: album.variousArtists,
          ),
          quiet,
        ),
        contextModalHeaderLine(album.title, theme.textTheme.titleMedium),
        if (details.isNotEmpty) contextModalHeaderLine(details, quiet),
      ],
      trailing: ContextModalComingSoonIconButton(
        icon: AppIcons.editAlbumArt,
        tooltip: l10n.albumModalEditAlbumArt,
      ),
      onTap: onTap,
      tapHint: l10n.songModalGoToAlbum,
    );
  }
}
