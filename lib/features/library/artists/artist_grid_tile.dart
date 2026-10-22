import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/artist_summaries.dart';
import '../../../shared/widgets/artist_avatar.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../albums/album_grid_tile.dart';
import '../widgets/library_rescan_button.dart';

const _padding = 8.0;
const _gap = 8.0;

/// One artist in a grid: round avatar, name, "N songs".
class ArtistGridTile extends StatelessWidget {
  const ArtistGridTile({
    super.key,
    required this.artist,
    required this.onTap,
    this.onQueueAction,
  });

  final ArtistSummary artist;
  final VoidCallback onTap;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  /// Height of a tile whose avatar is [width] wide: the avatar plus two text
  /// lines at the current text scale, so large text never overflows.
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

    final tile = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              // The avatar animates its size when the column width changes
              // (window resize); a fixed box keeps the column from
              // overflowing meanwhile.
              SizedBox.square(
                dimension: constraints.maxWidth,
                child: Center(
                  child: ArtistAvatar(
                    artistKey: artist.key,
                    name: artist.name,
                    size: constraints.maxWidth,
                  ),
                ),
              ),
              const SizedBox(height: _gap),
              Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                context.l10n.albumsSongCount(artist.songCount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return QueueActionsRegion(onAction: onQueueAction, child: tile);
  }
}

/// [artists] as a scrolling grid, leaving room for the rescan button below.
class ArtistGrid extends StatelessWidget {
  const ArtistGrid({
    super.key,
    required this.artists,
    required this.onTap,
    this.onQueueAction,
  });

  final List<ArtistSummary> artists;
  final void Function(ArtistSummary artist) onTap;

  /// An action picked from the menu of [artist]; no menus without it.
  final void Function(ArtistSummary artist, QueueAction action)? onQueueAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          albumGridPadding,
          0,
          albumGridPadding,
          libraryRescanClearance,
        ),
        gridDelegate: libraryGridDelegate(
          context,
          constraints.maxWidth - albumGridPadding * 2,
          tileHeight: ArtistGridTile.heightFor,
        ),
        itemCount: artists.length,
        itemBuilder: (context, i) => ArtistGridTile(
          artist: artists[i],
          onTap: () => onTap(artists[i]),
          onQueueAction: onQueueAction == null
              ? null
              : (action) => onQueueAction!(artists[i], action),
        ),
      ),
    );
  }
}
