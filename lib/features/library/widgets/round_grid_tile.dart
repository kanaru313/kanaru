import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/queue_actions_menu.dart';
import '../albums/album_grid_tile.dart';
import '../../../shared/fixed_line_strut.dart';

/// Height of a [RoundGridTile] whose avatar is [width] wide, for
/// [libraryGridDelegate]. The avatar is as wide as a square cover, so the
/// tile is as tall as an album tile.
double roundGridTileHeight(BuildContext context, double width) =>
    AlbumGridTile.heightFor(context, width);

/// One grid cell of a round picture, a name and a line below it (artists,
/// genres). [avatarBuilder] gets the diameter to fill the cell width.
class RoundGridTile extends StatelessWidget {
  const RoundGridTile({
    super.key,
    required this.avatarBuilder,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onQueueAction,
  });

  final Widget Function(double size) avatarBuilder;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tile = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(gridTilePadding),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              // The avatar animates its size when the column width changes
              // (window resize); a fixed box keeps the column from
              // overflowing meanwhile.
              SizedBox.square(
                dimension: constraints.maxWidth,
                child: Center(child: avatarBuilder(constraints.maxWidth)),
              ),
              const SizedBox(height: gridTileGap),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
                strutStyle: fixedLineStrut(theme.textTheme.titleSmall),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                strutStyle: fixedLineStrut(theme.textTheme.bodySmall),
              ),
            ],
          ),
        ),
      ),
    );
    return QueueActionsRegion(onAction: onQueueAction, child: tile);
  }
}
