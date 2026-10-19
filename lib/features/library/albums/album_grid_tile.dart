import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../widgets/album_artwork.dart';
import 'album_tile_data.dart';

const _padding = 8.0;
const _gap = 8.0;

/// One album in a grid: square artwork, title, "artist · year".
class AlbumGridTile extends StatelessWidget {
  const AlbumGridTile({super.key, required this.data, required this.onTap});

  final AlbumTileData data;
  final VoidCallback onTap;

  /// Height of a tile [width] wide: the square artwork plus two text lines
  /// at the current text scale, so large text never overflows.
  static double heightFor(BuildContext context, double width) {
    final theme = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle? style) {
      final size = style?.fontSize ?? 14;
      return scaler.scale(size) * (style?.height ?? 1.2);
    }

    return width +
        _gap +
        line(theme.titleSmall) +
        line(theme.bodySmall) +
        // Rounding slack so a fractional line height never clips.
        2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final subtitle = [
      data.artist ?? l10n.albumsUnknownArtist,
      if (data.year != null) '${data.year}',
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AlbumArtwork(albumKey: data.key, size: constraints.maxWidth),
              const SizedBox(height: _gap),
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [albums] as a grid of tiles at most 200 px wide, rows sized to fit the
/// artwork and two lines of text.
class AlbumGrid extends StatelessWidget {
  const AlbumGrid({super.key, required this.albums, required this.onTap});

  final List<AlbumTileData> albums;
  final void Function(AlbumTileData album) onTap;

  static const _maxTileWidth = 200.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const sidePadding = 24.0;
        final width = constraints.maxWidth - sidePadding * 2;
        final columns = (width / _maxTileWidth).ceil().clamp(1, 1 << 20);
        final tileWidth = width / columns;
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: sidePadding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent:
                AlbumGridTile.heightFor(context, tileWidth - _padding * 2) +
                _padding * 2,
          ),
          itemCount: albums.length,
          itemBuilder: (context, i) =>
              AlbumGridTile(data: albums[i], onTap: () => onTap(albums[i])),
        );
      },
    );
  }
}
