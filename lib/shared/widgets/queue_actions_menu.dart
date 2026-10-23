import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import 'menu_keyboard_region.dart';

/// What the menu of a song, album or artist can do.
///
/// [addToPlaylist] does not change the queue: `enqueueLoaded` and
/// `enqueueFromDatabase`, which every menu ends in, send it to the playlist
/// picker instead of `enqueueTracks`.
enum QueueAction { playNext, addToQueue, addToPlaylist }

/// A menu row: [icon] and [label], which shortens instead of overflowing
/// when a translation is long. A disabled row is greyed out.
PopupMenuItem<T> menuRow<T>(
  T value,
  IconData icon,
  String label, {
  bool enabled = true,
}) => PopupMenuItem(
  value: value,
  enabled: enabled,
  child: Row(
    children: [
      Icon(icon),
      const SizedBox(width: 12),
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
    ],
  ),
);

/// The three queue rows, each valued [toValue] of its action, so a menu with
/// more rows can share them.
List<PopupMenuEntry<T>> queueActionItems<T>(
  BuildContext context,
  T Function(QueueAction action) toValue,
) {
  final l10n = context.l10n;
  return [
    menuRow(
      toValue(QueueAction.playNext),
      AppIcons.playlistPlay,
      l10n.queuePlayNext,
    ),
    menuRow(
      toValue(QueueAction.addToQueue),
      AppIcons.addToQueue,
      l10n.queueAddToQueue,
    ),
    menuRow(
      toValue(QueueAction.addToPlaylist),
      AppIcons.addToPlaylist,
      l10n.playlistAddTo,
    ),
  ];
}

/// Where a menu with its corner at [position] (global) goes.
RelativeRect menuPositionAt(BuildContext context, Offset position) {
  // The menu is laid out in the overlay of the nearest navigator, which on
  // the wide layout does not start at the window's corner (the sidebar and
  // top bar sit outside it): so the point goes into its coordinates.
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
  final local = overlay.globalToLocal(position);
  return RelativeRect.fromRect(
    Rect.fromLTWH(local.dx, local.dy, 0, 0),
    Offset.zero & overlay.size,
  );
}

/// Opens the queue menu with its corner at [position] (global) and returns
/// the chosen action, or null when it was dismissed.
Future<QueueAction?> showQueueActionsMenu(
  BuildContext context,
  Offset position,
) => showMenu<QueueAction>(
  context: context,
  position: menuPositionAt(context, position),
  items: queueActionItems(context, (action) => action),
);

/// Opens the queue menu at the pointer on a right click or a long press of
/// [child], or at the row from the keyboard (Menu key, Shift+F10, see
/// [MenuKeyboardRegion]), and reports the chosen action to [onAction].
/// Without [onAction], [child] is returned as is.
class QueueActionsRegion extends StatelessWidget {
  const QueueActionsRegion({super.key, this.onAction, required this.child});

  final ValueChanged<QueueAction>? onAction;
  final Widget child;

  Future<void> _open(BuildContext context, Offset position) async {
    final action = await showQueueActionsMenu(context, position);
    if (action != null) onAction?.call(action);
  }

  @override
  Widget build(BuildContext context) {
    if (onAction == null) return child;
    return MenuKeyboardRegion(
      onOpen: (position) => _open(context, position),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (details) => _open(context, details.globalPosition),
        onLongPressStart: (details) => _open(context, details.globalPosition),
        child: child,
      ),
    );
  }
}

/// A "more" button with the queue menu, for the header of an album or
/// artist page.
class QueueActionsButton extends StatelessWidget {
  const QueueActionsButton({super.key, required this.onSelected});

  final ValueChanged<QueueAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<QueueAction>(
      tooltip: context.l10n.queueActionsTooltip,
      icon: const Icon(AppIcons.more),
      onSelected: onSelected,
      itemBuilder: (context) => queueActionItems(context, (action) => action),
    );
  }
}
