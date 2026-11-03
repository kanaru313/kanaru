import 'package:material_ui/material_ui.dart';

import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/context_menu_region.dart';
import '../../shared/widgets/playlist_cover.dart';

/// Height of one [CollageListRow].
const collageListRowExtent = 80.0;

/// One list row: collage, title and subtitle. Tapping opens it. With [onPlay]
/// it shows a play button. With [onOpenModal] a right click, a long press or
/// the menu key opens a context modal, and [trailing] ends the row. Without
/// them the row is tap-only.
class CollageListRow<T> extends StatelessWidget {
  const CollageListRow({
    super.key,
    required this.coverKeys,
    required this.seed,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onPlay,
    this.playTooltip,
    this.trailing,
    this.onOpenModal,
  });

  final List<String> coverKeys;

  /// Picks the collage's fallback colors when it has no covers.
  final String seed;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final String? playTooltip;

  /// Widget at the end of the row, such as a more button.
  final Widget? trailing;

  /// Opens the row's context modal; see [ContextMenuRegion].
  final void Function({required bool viaKeyboard})? onOpenModal;

  /// [onOpenModal] as a [ContextMenuOpen]: a modal has no anchor point.
  ContextMenuOpen? _modalOpener() {
    final open = onOpenModal;
    if (open == null) return null;
    return ({required viaKeyboard, required at}) =>
        open(viaKeyboard: viaKeyboard);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final row = Row(
      children: [
        PlaylistCover(coverKeys: coverKeys, size: 56, seed: seed),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (onPlay != null)
          IconButton(
            icon: const Icon(AppIcons.play),
            tooltip: playTooltip,
            onPressed: onPlay,
          ),
        ?trailing,
      ],
    );

    final card = Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: row,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: ContextMenuRegion(onOpen: _modalOpener(), child: card),
    );
  }
}
