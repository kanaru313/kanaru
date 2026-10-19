import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// How long the pointer must rest before the header and footer fade out.
const nowPlayingHideAfter = Duration(seconds: 3);

/// Pointer moves closer together than this count as one.
const _moveThrottle = Duration(milliseconds: 300);

/// Whether the header and footer of Now Playing show: they appear on any
/// pointer move or key press and fade out after [nowPlayingHideAfter] of
/// stillness, never while pinned (pointer on them, drawer or popup open).
class AutoHideController {
  /// `true` while the header and footer show.
  final visible = ValueNotifier<bool>(true);

  int _pins = 0;
  Timer? _hideTimer;
  Timer? _throttle;

  /// Shows the chrome and restarts the countdown. Pointer moves are
  /// throttled so a busy mouse does not reset a timer hundreds of times.
  void poke({bool throttled = false}) {
    if (throttled && _throttle != null) return;
    if (throttled) _throttle = Timer(_moveThrottle, () => _throttle = null);
    visible.value = true;
    _restart();
  }

  /// Keeps the chrome shown until a matching [unpin].
  void pin() {
    _pins++;
    _hideTimer?.cancel();
    visible.value = true;
  }

  void unpin() {
    if (_pins > 0) _pins--;
    _restart();
  }

  /// The pointer left the window: nothing to move it back, so hide now.
  void hideNow() {
    if (_pins > 0) return;
    _hideTimer?.cancel();
    visible.value = false;
  }

  void _restart() {
    _hideTimer?.cancel();
    if (_pins > 0) return;
    _hideTimer = Timer(nowPlayingHideAfter, () => visible.value = false);
  }

  void dispose() {
    _hideTimer?.cancel();
    _throttle?.cancel();
    visible.dispose();
  }
}

/// Shows [child] while [controller] says so, fading it in and out. Hidden
/// means unclickable but still laid out, so the content between the header and
/// footer does not jump. The pointer resting on [child] keeps it shown.
class AutoHide extends StatelessWidget {
  const AutoHide({super.key, required this.controller, required this.child});

  final AutoHideController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.visible,
      builder: (context, visible, child) => IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          // Quick in, slower out, both eased.
          duration: Duration(milliseconds: visible ? 150 : 100),
          curve: Curves.easeInOut,
          child: child,
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => controller.pin(),
        onExit: (_) => controller.unpin(),
        child: child,
      ),
    );
  }
}

/// Wraps the whole screen: pointer moves and key presses show the chrome,
/// leaving the window hides it, and the cursor disappears with it.
class AutoHideRegion extends StatelessWidget {
  const AutoHideRegion({
    super.key,
    required this.controller,
    required this.child,
  });

  final AutoHideController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.visible,
      builder: (context, visible, child) => MouseRegion(
        cursor: visible ? MouseCursor.defer : SystemMouseCursors.none,
        onHover: (_) => controller.poke(throttled: true),
        onExit: (_) => controller.hideNow(),
        child: child,
      ),
      child: child,
    );
  }
}
