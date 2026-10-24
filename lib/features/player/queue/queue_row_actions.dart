import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import 'queue_input_kind.dart';

/// Width of the remove button and of the drag handle, the slots the actions
/// keep whether they are shown or not so durations line up.
const queueRowActionWidth = 36.0;

/// Tells its builder whether the actions of a row should be shown: while the
/// mouse is over the row or keyboard focus is anywhere inside it.
///
/// The focus part is what makes the hidden actions reachable without a
/// mouse: Tab onto the row reveals its remove button, and the next Tab
/// reaches it.
class QueueRowReveal extends StatefulWidget {
  const QueueRowReveal({super.key, required this.builder});

  final Widget Function(BuildContext context, bool revealed) builder;

  @override
  State<QueueRowReveal> createState() => _QueueRowRevealState();
}

class _QueueRowRevealState extends State<QueueRowReveal> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: Focus(
      // Only watches focus inside the row; it is not a stop of its own.
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: Builder(
        builder: (context) => widget.builder(context, _hovered || _focused),
      ),
    ),
  );
}

/// Keeps [child] in the layout and in the semantics tree while it is not
/// [visible], but invisible, not hit-testable and out of the focus order, so
/// screen readers still reach it and nothing can be pressed by accident.
class _Revealed extends StatelessWidget {
  const _Revealed({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => Visibility(
    visible: visible,
    maintainSize: true,
    maintainState: true,
    maintainAnimation: true,
    maintainSemantics: true,
    child: child,
  );
}

/// The trailing controls of a queue row: remove, then the drag handle.
///
/// Both show on hover or focus inside the row ([revealed]). The handle also
/// stays in view while the user works by touch, which has no hover. A null
/// [onRemove] leaves the remove slot empty; a null [dragIndex] leaves the
/// handle slot empty (the playing row and the earlier ones are not dragged).
class QueueRowActions extends StatelessWidget {
  const QueueRowActions({
    super.key,
    required this.revealed,
    this.onRemove,
    this.dragIndex,
    this.reserveHandle = true,
  });

  final bool revealed;
  final VoidCallback? onRemove;

  /// Index of the row in its reorderable list, for the handle.
  final int? dragIndex;

  /// Keep an empty slot where the handle would be, so a row that cannot be
  /// dragged lines up with one that can.
  final bool reserveHandle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final touch = QueueInputScope.touchOf(context);
    final remove = onRemove;
    final index = dragIndex;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (remove != null)
          _Revealed(
            visible: revealed,
            child: Semantics(
              label: l10n.queueRemove,
              button: true,
              onTap: remove,
              excludeSemantics: true,
              child: IconButton(
                icon: const Icon(AppIcons.close),
                iconSize: 20,
                tooltip: l10n.queueRemove,
                onPressed: remove,
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(queueRowActionWidth),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
        if (index != null)
          _Revealed(
            visible: revealed || touch,
            child: Semantics(
              label: l10n.queueReorder,
              // Its own node, so the row's label stays the track.
              container: true,
              child: ReorderableDragStartListener(
                index: index,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Tooltip(
                    message: l10n.queueReorder,
                    child: const SizedBox.square(
                      dimension: queueRowActionWidth,
                      child: Icon(AppIcons.dragHandle, size: 20),
                    ),
                  ),
                ),
              ),
            ),
          )
        else if (reserveHandle)
          const SizedBox(width: queueRowActionWidth),
      ],
    );
  }
}
