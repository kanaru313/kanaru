import 'dart:async';

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

class _WindowDragAreaState extends ConsumerState<WindowDragArea> {
  /// Pointers a [WindowDragExclusion] descendant took on pointer down.
  final _excluded = <int>{};
  Offset? _downPosition;
  Offset? _lastClickPosition;

  /// Forgets the first click once a second one can no longer pair with it.
  Timer? _doubleClickWindow;

  void _onPointerDown(PointerDownEvent event) {
    // Only a plain primary click can be half of a double click.
    _downPosition = event.buttons == kPrimaryButton ? event.position : null;
  }

  void _onPointerUp(PointerUpEvent event) {
    final downPosition = _downPosition;
    _downPosition = null;
    final taken = _excluded.remove(event.pointer);
    if (!widget.doubleClickMaximizes) return;
    // A drag is not a click; neither is a click on an interactive child.
    if (downPosition == null ||
        taken ||
        (event.position - downPosition).distance > kDoubleTapSlop) {
      _resetClicks();
      return;
    }

    final lastPosition = _lastClickPosition;
    if (lastPosition != null &&
        (event.position - lastPosition).distance <= kDoubleTapSlop) {
      _resetClicks();
      ref.read(toggleMaximizeProvider)();
    } else {
      _resetClicks();
      _lastClickPosition = event.position;
      _doubleClickWindow = Timer(kDoubleTapTimeout, _resetClicks);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _excluded.remove(event.pointer);
    _downPosition = null;
    _resetClicks();
  }

  void _resetClicks() {
    _doubleClickWindow?.cancel();
    _doubleClickWindow = null;
    _lastClickPosition = null;
  }

  @override
  void dispose() {
    _doubleClickWindow?.cancel();
    super.dispose();
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
