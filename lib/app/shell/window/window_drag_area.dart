import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'desktop_window.dart';

/// How far a press may move and still count as a click. Matches GTK's default
/// drag threshold, so a mouse that jitters during a double click does not
/// start a window drag.
const _dragSlop = 8.0;

/// Lets the user move the window by dragging [child] and maximize it with a
/// double click, like a native title bar. Does nothing without a custom
/// title bar.
///
/// The window drag starts only once the pointer moves past the click slop. A
/// drag recognizer would win the gesture arena at pointer down and start the
/// drag on every press; on Linux that hands the pointer to the window manager,
/// which swallows the release, so no click could be counted.
///
/// The double click is counted from raw pointer events, not with
/// `GestureDetector.onDoubleTap`: that recognizer holds the gesture arena for
/// the double tap timeout, which delays every tap on a button inside by
/// about 300 ms. Wrap interactive children in [WindowDragExclusion] so their
/// clicks never count.
class WindowDragArea extends ConsumerStatefulWidget {
  const WindowDragArea({
    super.key,
    required this.child,
    this.doubleClickMaximizes = true,
  });

  final Widget child;

  /// Set to `false` when [child] holds interactive widgets that cannot be
  /// wrapped in [WindowDragExclusion]; dragging still works.
  final bool doubleClickMaximizes;

  @override
  ConsumerState<WindowDragArea> createState() => _WindowDragAreaState();
}

class _WindowDragAreaState extends ConsumerState<WindowDragArea> {
  /// Pointers a [WindowDragExclusion] descendant took on pointer down.
  final _excluded = <int>{};

  /// Where and when each pressed primary-button pointer went down.
  final _downs = <int, ({Offset position, Duration time})>{};

  /// Pointers that already started a window drag; their release is not a click.
  final _dragged = <int>{};

  /// The last completed click, which a second one may pair with.
  ({Offset position, Duration time})? _lastClick;

  void _onPointerDown(PointerDownEvent event) {
    _dragged.remove(event.pointer);
    // Only a plain primary press can start a drag or be half of a double click.
    if (event.buttons == kPrimaryButton) {
      _downs[event.pointer] = (position: event.position, time: event.timeStamp);
    } else {
      _downs.remove(event.pointer);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final down = _downs[event.pointer];
    if (down == null ||
        _excluded.contains(event.pointer) ||
        _dragged.contains(event.pointer)) {
      return;
    }
    if ((event.position - down.position).distance <= _dragSlop) return;
    _dragged.add(event.pointer);
    ref.read(startWindowDragProvider)();
  }

  void _onPointerUp(PointerUpEvent event) {
    final down = _downs.remove(event.pointer);
    final taken = _excluded.remove(event.pointer);
    final dragged = _dragged.remove(event.pointer);
    if (!widget.doubleClickMaximizes) return;
    // A drag is not a click; neither is a click on an interactive child.
    if (down == null ||
        taken ||
        dragged ||
        (event.position - down.position).distance > _dragSlop) {
      _lastClick = null;
      return;
    }

    final last = _lastClick;
    if (last != null &&
        down.time - last.time <= kDoubleTapTimeout &&
        (event.position - last.position).distance <= kDoubleTapSlop) {
      _lastClick = null;
      ref.read(toggleMaximizeProvider)();
    } else {
      _lastClick = (position: event.position, time: event.timeStamp);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _excluded.remove(event.pointer);
    _downs.remove(event.pointer);
    _dragged.remove(event.pointer);
    _lastClick = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(customTitleBarProvider)) return widget.child;

    return _DragAreaScope(
      excluded: _excluded,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: widget.child,
      ),
    );
  }
}

class _DragAreaScope extends InheritedWidget {
  const _DragAreaScope({required this.excluded, required super.child});

  final Set<int> excluded;

  @override
  bool updateShouldNotify(_DragAreaScope oldWidget) =>
      excluded != oldWidget.excluded;
}

/// Marks [child] as interactive inside a [WindowDragArea]: pointer events that
/// start on it do not count towards the double click that maximizes the
/// window, so double clicking a button or selecting a word in a search field
/// leaves the window alone.
class WindowDragExclusion extends StatelessWidget {
  const WindowDragExclusion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_DragAreaScope>();
    if (scope == null) return child;
    // A descendant listener gets the event before the ancestor one, so the
    // area knows the pointer is taken by the time it sees the pointer up.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => scope.excluded.add(event.pointer),
      child: child,
    );
  }
}
