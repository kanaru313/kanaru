import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:material_ui/material_ui.dart';

/// Tells the rows of the queue whether the user is working with touch (or a
/// stylus) or with a mouse, so a row can keep its drag handle in view for a
/// finger, which has no hover to reveal it.
///
/// Starts as touch when no mouse is connected (phones, tablets and touch
/// screens of laptops without one) and follows the last pointer that was
/// pressed or, for a mouse, moved over the list.
class QueueInputScope extends StatefulWidget {
  const QueueInputScope({super.key, required this.child});

  final Widget child;

  /// Whether the last input was touch or a stylus. Rebuilds the caller only
  /// when that changes.
  static bool touchOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_QueueInput>()?.touch ??
      _platformIsTouch;

  /// Whether to assume touch before any pointer was seen.
  static bool get _platformIsTouch =>
      !RendererBinding.instance.mouseTracker.mouseIsConnected;

  @override
  State<QueueInputScope> createState() => _QueueInputScopeState();
}

class _QueueInputScopeState extends State<QueueInputScope> {
  var _touch = QueueInputScope._platformIsTouch;

  void _seen(PointerDeviceKind kind) {
    final touch =
        kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus;
    if (touch != _touch) setState(() => _touch = touch);
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) => _seen(event.kind),
    onPointerHover: (event) => _seen(event.kind),
    child: _QueueInput(touch: _touch, child: widget.child),
  );
}

/// Hands [touch] to the rows under [child] when they sit outside the
/// [QueueInputScope], like the lifted row of a drag in the overlay.
class QueueInputValue extends StatelessWidget {
  const QueueInputValue({super.key, required this.touch, required this.child});

  final bool touch;
  final Widget child;

  @override
  Widget build(BuildContext context) => _QueueInput(touch: touch, child: child);
}

class _QueueInput extends InheritedWidget {
  const _QueueInput({required this.touch, required super.child});

  final bool touch;

  @override
  bool updateShouldNotify(_QueueInput old) => touch != old.touch;
}

/// Whether a pointer of [kind] may remove a row by swiping it: a finger or a
/// stylus does; a mouse and a trackpad never do (a drag with them is a
/// slip, and has the row handle for moving).
bool queueSwipeRemoves(PointerDeviceKind kind) =>
    kind == PointerDeviceKind.touch ||
    kind == PointerDeviceKind.stylus ||
    kind == PointerDeviceKind.invertedStylus;
