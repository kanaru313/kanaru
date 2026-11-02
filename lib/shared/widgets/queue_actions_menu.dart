import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import 'context_menu_region.dart';

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

/// Opens a popup menu of [items] with its corner at [at] (global) and
/// returns the picked value, or null when it was dismissed.
///
/// Opened [viaKeyboard] (the Menu key, Shift+F10, Enter or Space on a ⋮
/// button), or with a screen reader on, its first enabled row takes focus
/// two frames after the route is pushed, as in the context modal. A pointer
/// open focuses nothing.
Future<T?> showContextMenu<T>(
  BuildContext context, {
  required Offset at,
  required List<PopupMenuEntry<T>> items,
  bool viaKeyboard = false,
}) {
  final focusFirstRow =
      viaKeyboard || MediaQuery.maybeAccessibleNavigationOf(context) == true;
  final result = showMenu<T>(
    context: context,
    position: menuPositionAt(context, at),
    items: items,
  );
  if (focusFirstRow) _focusFirstMenuRow();
  return result;
}

/// Moves focus to the first enabled row of the popup menu just pushed.
void _focusFirstMenuRow() {
  // Two frames: the first builds the route and gives its scope focus.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Acts only while focus is on the scope of a popup that is still on
      // top with no row focused yet: an Esc or Enter in between closed the
      // menu (focus is back on the row), or the user moved focus already.
      final focus = FocusManager.instance.primaryFocus;
      final focusContext = focus?.context;
      if (focus is! FocusScopeNode || focusContext == null) return;
      final route = ModalRoute.of(focusContext);
      if (route is! PopupRoute || !route.isCurrent) return;
      focus.nextFocus();
    });
    WidgetsBinding.instance.scheduleFrame();
  });
}

/// Opens the queue menu with its corner at [position] (global) and returns
/// the chosen action, or null when it was dismissed.
Future<QueueAction?> showQueueActionsMenu(
  BuildContext context,
  Offset position, {
  bool viaKeyboard = false,
}) => showContextMenu<QueueAction>(
  context,
  at: position,
  items: queueActionItems(context, (action) => action),
  viaKeyboard: viaKeyboard,
);

/// Opens the queue menu at the pointer on a right click or a long press of
/// [child], or at the row from the keyboard (Menu key, Shift+F10, see
/// [ContextMenuRegion]), and reports the chosen action to [onAction].
/// Without [onAction], [child] is returned as is.
class QueueActionsRegion extends StatelessWidget {
  const QueueActionsRegion({super.key, this.onAction, required this.child});

  final ValueChanged<QueueAction>? onAction;
  final Widget child;

  Future<void> _open(
    BuildContext context,
    Offset position, {
    required bool viaKeyboard,
  }) async {
    final action = await showQueueActionsMenu(
      context,
      position,
      viaKeyboard: viaKeyboard,
    );
    if (action != null) onAction?.call(action);
  }

  @override
  Widget build(BuildContext context) => ContextMenuRegion(
    onOpen: onAction == null
        ? null
        : ({required viaKeyboard, required at}) =>
              _open(context, at, viaKeyboard: viaKeyboard),
    child: child,
  );
}

/// A "more" button with the queue menu, for the header of an album or
/// artist page.
class QueueActionsButton extends StatelessWidget {
  const QueueActionsButton({super.key, required this.onSelected});

  final ValueChanged<QueueAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<QueueAction>(
      tooltip: context.l10n.songModalMoreOptions,
      icon: const Icon(AppIcons.more),
      onSelected: onSelected,
      itemBuilder: (context) => queueActionItems(context, (action) => action),
    );
  }
}
