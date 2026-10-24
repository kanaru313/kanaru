import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/playlist_cover.dart';
import '../../shared/fixed_line_strut.dart';

/// Space around the whole grid.
const _gridPadding = 24.0;

/// Space between a card's edge and its cover and text.
const _cardPadding = 8.0;

/// Space between the cover and the name.
const _gap = 8.0;

/// Widest a card grows; the column count follows from it.
const _maxCardWidth = 200.0;

/// Height of a card [width] wide: the square cover plus a name of two lines
/// and a count at the current text scale, so large text never overflows.
double _cardHeight(BuildContext context, double width) {
  final theme = Theme.of(context).textTheme;
  final scaler = MediaQuery.textScalerOf(context);
  double line(TextStyle? style) =>
      scaler.scale(style?.fontSize ?? 14) * (style?.height ?? 1.2);
  return width +
      _gap +
      line(theme.titleSmall) * 2 +
      line(theme.bodySmall) +
      // Rounding slack so a fractional line height never clips.
      2;
}

/// Every playlist as a card: collage, name (two lines at most) and count.
class PlaylistsGrid extends StatelessWidget {
  const PlaylistsGrid({
    super.key,
    required this.cards,
    required this.onOpen,
    this.emptyAction,
  });

  final List<PlaylistCard> cards;
  final ValueChanged<PlaylistSummary> onOpen;

  /// Shown under the message when there are no playlists.
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (cards.isEmpty) {
      return EmptyState(
        icon: AppIcons.playlist,
        title: l10n.sidebarNoPlaylists,
        message: l10n.playlistsEmptyMessage,
        action: emptyAction,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Columns of cards at most 200 px wide, rows tall enough for the
        // text; a max-extent delegate would make the cells square.
        final width = constraints.maxWidth - _gridPadding * 2;
        final columns = (width / _maxCardWidth).ceil().clamp(1, 1 << 20);
        final cardWidth = width / columns;
        return GridView.builder(
          padding: const EdgeInsets.all(_gridPadding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent:
                _cardHeight(context, cardWidth - _cardPadding * 2) +
                _cardPadding * 2,
          ),
          itemCount: cards.length,
          itemBuilder: (context, i) => _PlaylistCardTile(
            card: cards[i],
            onTap: () => onOpen(cards[i].playlist),
          ),
        );
      },
    );
  }
}

class _PlaylistCardTile extends StatelessWidget {
  const _PlaylistCardTile({required this.card, required this.onTap});

  final PlaylistCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlist = card.playlist;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(_cardPadding),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlaylistCover(
                coverKeys: card.coverKeys,
                size: constraints.maxWidth,
                seed: 'playlist:${playlist.id}',
              ),
              const SizedBox(height: _gap),
              Text(
                playlist.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
                strutStyle: fixedLineStrut(theme.textTheme.titleSmall),
              ),
              Text(
                context.l10n.playlistTrackCount(playlist.entryCount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
  }
}
