import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/playlist_cover.dart';
import '../widgets/detail_side_pane.dart';

/// Side of the card over the backdrop (75% of the pane).
const genreHeroCardSize = 240.0;

const _border = 4.0;
const _outerRadius = 16.0;
const _backdropOpacity = 0.35;

/// Side the collage is built at, in both the card and the backdrop. The
/// backdrop is scaled up from it at paint time, so both layers ask for the
/// same image sizes and each cover is decoded once.
const genreHeroCoverSize = genreHeroCardSize - 2 * _border;

/// The genre collage enlarged to the pane's width and washed out, with no
/// blur. Built at [genreHeroCoverSize] and stretched, so it shares its
/// decoded images with [GenreHeroCard].
class GenreHeroBackdrop extends StatelessWidget {
  const GenreHeroBackdrop({
    super.key,
    required this.coverKeys,
    required this.seed,
    required this.icon,
  });

  final List<String> coverKeys;
  final String seed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: detailSidePaneWidth,
      child: Opacity(
        opacity: _backdropOpacity,
        child: FittedBox(
          fit: BoxFit.fill,
          child: PlaylistCover(
            coverKeys: coverKeys,
            size: genreHeroCoverSize,
            radius: 0,
            seed: seed,
            icon: icon,
          ),
        ),
      ),
    );
  }
}

/// The genre collage as a rounded card with a light border and a drop
/// shadow, drawn over [GenreHeroBackdrop]. Same build size as the backdrop's
/// collage, so the covers are decoded once.
class GenreHeroCard extends StatelessWidget {
  const GenreHeroCard({
    super.key,
    required this.coverKeys,
    required this.seed,
    required this.icon,
  });

  final List<String> coverKeys;
  final String seed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(_outerRadius),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(_border),
        child: PlaylistCover(
          coverKeys: coverKeys,
          size: genreHeroCoverSize,
          radius: _outerRadius - _border,
          seed: seed,
          icon: icon,
        ),
      ),
    );
  }
}
