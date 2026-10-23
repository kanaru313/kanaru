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
/// footer does not jump, and its animations stand still once the fade-out is
/// over. The pointer resting on [child] keeps it shown.
class AutoHide extends StatefulWidget {
  const AutoHide({super.key, required this.controller, required this.child});

  final AutoHideController controller;
  final Widget child;

  @override
  State<AutoHide> createState() => _AutoHideState();
}

class _AutoHideState extends State<AutoHide> {
  /// Whether this widget holds a pin, i.e. the pointer is on it.
  bool _pinned = false;

  /// Whether the fade-out has finished, so [child] is invisible for good
  /// until the chrome shows again.
  late bool _fadedOut = !widget.controller.visible.value;

  @override
  void initState() {
    super.initState();
    widget.controller.visible.addListener(_onVisible);
  }

  void _onVisible() {
    // Without motion no fade-out ends to say so. The builder ignores this
    // flag then, but it keeps the tickers muted if motion comes back while
    // hidden.
    if (!widget.controller.visible.value &&
        MediaQuery.disableAnimationsOf(context)) {
      _fadedOut = true;
      return;
    }
    if (_fadedOut && widget.controller.visible.value) {
      setState(() => _fadedOut = false);
    }
  }

  void _setPinned(bool pinned) {
    if (_pinned == pinned) return;
    _pinned = pinned;
    pinned ? widget.controller.pin() : widget.controller.unpin();
  }

  @override
  void didUpdateWidget(AutoHide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.visible.removeListener(_onVisible);
    widget.controller.visible.addListener(_onVisible);
    _fadedOut = !widget.controller.visible.value;
    if (_pinned) {
      oldWidget.controller.unpin();
      widget.controller.pin();
    }
  }

  @override
  void dispose() {
    widget.controller.visible.removeListener(_onVisible);
    // A MouseRegion that leaves the tree under the pointer (e.g. the window
    // turning narrow) gets no exit, so give the pin back here.
    if (_pinned) widget.controller.unpin();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.visible,
      builder: (context, visible, child) {
        // Without motion the fade ends inside this build, where onEnd may
        // not set state; nothing is left to fade out, so mute at once.
        final still = MediaQuery.disableAnimationsOf(context);
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            // Quick in, slower out, both eased.
            duration: still
                ? Duration.zero
                : Duration(milliseconds: visible ? 150 : 100),
            curve: Curves.easeInOut,
            onEnd: () {
              if (!still && !widget.controller.visible.value) {
                setState(() => _fadedOut = true);
              }
            },
            // Muted tickers schedule no frames, and Riverpod consumers below
            // stop rebuilding on position ticks nobody sees.
            child: TickerMode(
              enabled: visible || (!still && !_fadedOut),
              child: child!,
            ),
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => _setPinned(true),
        onExit: (_) => _setPinned(false),
        child: widget.child,
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
