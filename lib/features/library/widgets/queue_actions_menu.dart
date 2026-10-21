import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';

/// What the queue menu of a song, album or artist can do.
enum QueueAction { playNext, addToQueue }

List<PopupMenuEntry<QueueAction>> _items(BuildContext context) {
  final l10n = context.l10n;
  PopupMenuItem<QueueAction> item(
    QueueAction action,
    IconData icon,
    String label,
  ) => PopupMenuItem(
    value: action,
    child: Row(children: [Icon(icon), const SizedBox(width: 12), Text(label)]),
  );
  return [
    item(QueueAction.playNext, Icons.playlist_play, l10n.queuePlayNext),
    item(QueueAction.addToQueue, Icons.playlist_add, l10n.queueAddToQueue),
  ];
}

/// Opens the queue menu with its corner at [position] (global) and returns
/// the chosen action, or null when it was dismissed.
Future<QueueAction?> showQueueActionsMenu(
  BuildContext context,
  Offset position,
) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  return showMenu<QueueAction>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 0, 0),
      Offset.zero & overlay.size,
    ),
    items: _items(context),
  );
}

/// Opens the queue menu at the pointer on a right click or a long press of
/// [child], and reports the chosen action to [onAction]. Without
/// [onAction], [child] is returned as is.
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
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (details) => _open(context, details.globalPosition),
      onLongPressStart: (details) => _open(context, details.globalPosition),
      child: child,
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
      icon: const Icon(Icons.more_vert),
      onSelected: onSelected,
      itemBuilder: _items,
    );
  }
}
