import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/menu_keyboard_region.dart';
import '../../shared/widgets/playlist_cover.dart';
import '../../shared/widgets/queue_actions_menu.dart' show menuPositionAt;

/// Height of one [CollageListRow].
const collageListRowExtent = 80.0;

/// One list row: collage, title and subtitle. Tapping opens it. With [onPlay]
/// it shows a play button; with [menuItems] and [onMenuSelected] it shows a
/// menu button that also opens on a right click, a long press or the menu
/// key. Without them the row is tap-only.
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
    this.menuItems,
    this.onMenuSelected,
  }) : assert(
         (menuItems == null) == (onMenuSelected == null),
         'menuItems and onMenuSelected go together',
       );

  final List<String> coverKeys;

  /// Picks the collage's fallback colors when it has no covers.
  final String seed;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final String? playTooltip;
  final List<PopupMenuEntry<T>> Function(BuildContext context)? menuItems;
  final ValueChanged<T>? onMenuSelected;

  Future<void> _openMenu(BuildContext context, Offset position) async {
    final builder = menuItems;
    final selected = onMenuSelected;
    if (builder == null || selected == null) return;
    final value = await showMenu<T>(
      context: context,
      position: menuPositionAt(context, position),
      items: builder(context),
    );
    if (value != null && context.mounted) selected(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasMenu = menuItems != null && onMenuSelected != null;

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
        if (hasMenu)
          PopupMenuButton<T>(
            tooltip: context.l10n.queueActionsTooltip,
            icon: const Icon(AppIcons.more),
            onSelected: onMenuSelected,
            itemBuilder: menuItems!,
          ),
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
      child: hasMenu
          ? MenuKeyboardRegion(
              onOpen: (position) => _openMenu(context, position),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onSecondaryTapUp: (d) => _openMenu(context, d.globalPosition),
                onLongPressStart: (d) => _openMenu(context, d.globalPosition),
                child: card,
              ),
            )
          : card,
    );
  }
}
