import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/icons/app_icons.dart';

/// Space the list keeps under its last row so the floating button never
/// covers a row's buttons: the button's size plus its margin.
const queueLocateClearance = 72.0;

/// Where the playing row is relative to the visible part of the list.
enum LocateSide { none, up, down }

/// Whether the row [index] of a list of rows [extent] tall is fully above
/// ([LocateSide.up]) or fully below ([LocateSide.down]) the viewport that
/// starts at [offset] and is [viewport] tall. A row that shows even a pixel
/// gives [LocateSide.none]. O(1): all rows have the same height.
LocateSide locateSide({
  required double offset,
  required double viewport,
  required double extent,
  required int index,
}) {
  if (index < 0 || extent <= 0) return LocateSide.none;
  if ((index + 1) * extent <= offset) return LocateSide.up;
  if (index * extent >= offset + viewport) return LocateSide.down;
  return LocateSide.none;
}

/// A small button that fades in while the playing row is scrolled out of
/// view; its arrow points toward the row and pressing it calls [onPressed].
///
/// Only this widget listens to the scroll, and it rebuilds only when the
/// side changes, so the rows never rebuild on scroll. The side is also
/// recomputed when [relayout] fires (viewport resized, list attached again),
/// when [currentIndex] or [extent] change (the track advanced off screen),
/// and once after the first frame. While [dragging] is true it stays hidden,
/// so it never sits under the dragged row.
///
/// Pressing it hides it and drops its keyboard focus; the header jump button
/// is the stable path for keyboard users.
class QueueLocateButton extends StatefulWidget {
  const QueueLocateButton({
    super.key,
    required this.controller,
    required this.extent,
    required this.currentIndex,
    required this.itemCount,
    required this.relayout,
    required this.dragging,
    required this.onPressed,
  });

  final ScrollController controller;
  final double extent;
  final int currentIndex;
  final int itemCount;

  /// Fires when the scroll metrics (viewport, content size) changed.
  final Listenable relayout;
  final ValueListenable<bool> dragging;
  final VoidCallback onPressed;

  @override
  State<QueueLocateButton> createState() => _QueueLocateButtonState();
}

class _QueueLocateButtonState extends State<QueueLocateButton> {
  static const _fade = Duration(milliseconds: 150);

  late final Listenable _sources = Listenable.merge([
    widget.controller,
    widget.relayout,
    widget.dragging,
  ]);
  LocateSide _side = LocateSide.none;

  /// Last side shown, so the arrow keeps its direction while fading out.
  LocateSide _lastShown = LocateSide.up;
  bool _fadingOut = false;

  @override
  void initState() {
    super.initState();
    _sources.addListener(_update);
    SchedulerBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void didUpdateWidget(QueueLocateButton old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex ||
        old.extent != widget.extent ||
        old.itemCount != widget.itemCount) {
      _update();
    }
  }

  @override
  void dispose() {
    _sources.removeListener(_update);
    super.dispose();
  }

  LocateSide _compute() {
    final controller = widget.controller;
    if (widget.dragging.value ||
        widget.itemCount < 2 ||
        !controller.hasClients ||
        !controller.position.hasViewportDimension) {
      return LocateSide.none;
    }
    return locateSide(
      offset: controller.offset,
      viewport: controller.position.viewportDimension,
      extent: widget.extent,
      index: widget.currentIndex,
    );
  }

  void _update() {
    if (!mounted) return;
    final next = _compute();
    if (next == _side) return;
    // May run while the framework builds (didUpdateWidget) or from a scroll
    // notification; setState is safe in both.
    setState(() {
      if (next == LocateSide.none) {
        _fadingOut = !MediaQuery.disableAnimationsOf(context);
      } else {
        _lastShown = next;
        _fadingOut = false;
      }
      _side = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shown = _side != LocateSide.none;
    // Not in the tree at rest: its tooltip and focus stop must not exist
    // while it is hidden.
    if (!shown && !_fadingOut) return const SizedBox.shrink();
    final label = AppLocalizations.of(context).queueShowCurrent;
    final animate = !MediaQuery.disableAnimationsOf(context);
    return AnimatedOpacity(
      opacity: shown ? 1 : 0,
      duration: animate ? _fade : Duration.zero,
      onEnd: () {
        if (mounted && _fadingOut) setState(() => _fadingOut = false);
      },
      child: ExcludeFocus(
        excluding: !shown,
        child: IgnorePointer(
          ignoring: !shown,
          child: ExcludeSemantics(
            excluding: !shown,
            child: Semantics(
              button: true,
              focusable: true,
              label: label,
              excludeSemantics: true,
              onTap: widget.onPressed,
              child: IconButton.filledTonal(
                tooltip: label,
                onPressed: widget.onPressed,
                icon: Icon(
                  _lastShown == LocateSide.up
                      ? AppIcons.locateUp
                      : AppIcons.locateDown,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
