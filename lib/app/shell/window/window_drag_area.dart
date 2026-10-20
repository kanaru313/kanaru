import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_window.dart';

/// Lets the user move the window by dragging [child] and maximize it with a
/// double click, like a native title bar. Does nothing without a custom
/// title bar.
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

/// Whether a release [released] after a press at [pressed] ends a window
/// drag rather than a click.
///
/// The pan recognizer is alone in its arena, so it wins at pointer down and
/// every press starts a window drag; "the drag started" says nothing. On
/// Linux the window manager then grabs the pointer and, once the user lets go,
/// sends a synthetic release at the press position. Such a release looks like
/// a click in place, but it comes long after the press.
bool _isWindowDragRelease(Duration pressed, Duration released) =>
    released - pressed > kLongPressTimeout;

class _WindowDragAreaState extends ConsumerState<WindowDragArea> {
  /// Pointers a [WindowDragExclusion] descendant took on pointer down.
  final _excluded = <int>{};

  /// Where and when each pressed primary-button pointer went down.
  final _downs = <int, ({Offset position, Duration time})>{};

  /// The last completed click, which a second one may pair with.
  ({Offset position, Duration time})? _lastClick;

  void _onPointerDown(PointerDownEvent event) {
    // Only a plain primary click can be half of a double click.
    if (event.buttons == kPrimaryButton) {
      _downs[event.pointer] = (position: event.position, time: event.timeStamp);
    } else {
      _downs.remove(event.pointer);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final down = _downs.remove(event.pointer);
    final taken = _excluded.remove(event.pointer);
    if (!widget.doubleClickMaximizes) return;
    final slop = computeHitSlop(
      event.kind,
      MediaQuery.maybeGestureSettingsOf(context),
    );
    // A drag is not a click (see [_isWindowDragRelease]); neither is a click
    // on an interactive child.
    if (down == null ||
        taken ||
        _isWindowDragRelease(down.time, event.timeStamp) ||
        (event.position - down.position).distance > slop) {
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
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) => windowManager.startDragging(),
          child: widget.child,
        ),
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
