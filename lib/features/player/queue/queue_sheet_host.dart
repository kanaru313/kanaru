import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import 'queue_panel.dart';

/// Widest the queue sheet gets.
const queueSheetWidth = 400.0;

/// Same timing as the sidebar collapsing, so the two feel alike.
const queueSheetDuration = Duration(milliseconds: 400);
const queueSheetCurve = Curves.easeInOutCubic;

/// Opacity of the black scrim behind the sheet.
const _scrimAlpha = 0.5;

/// Opens and closes the queue sheet of the nearest [QueueSheetHost].
abstract interface class QueueSheetController {
  bool get isOpen;
  void open();
  void close();
}

/// Lays a queue side sheet over [child]: a dark scrim that fades in over the
/// whole host, and the queue panel sliding in from the right edge. It is not
/// a route, so each host (the app shell, Now Playing) has its own sheet and
/// nothing global tracks it.
///
/// While open, focus moves into the sheet (Esc closes it, Tab stays inside)
/// and returns to where it was once the sheet has slid away.
class QueueSheetHost extends StatefulWidget {
  const QueueSheetHost({
    super.key,
    required this.child,
    this.onOpenChanged,
    this.onMouseBack,
    this.onMouseForward,
  });

  final Widget child;

  /// The mouse back and forward side buttons when the sheet is closed. While
  /// it is open, back closes it (like Esc) and forward does nothing.
  final VoidCallback? onMouseBack;
  final VoidCallback? onMouseForward;

  /// Called when the sheet starts opening (`true`) or closing (`false`).
  final ValueChanged<bool>? onOpenChanged;

  static QueueSheetController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_QueueSheetScope>()?.controller;

  static QueueSheetController of(BuildContext context) {
    final controller = maybeOf(context);
    if (controller == null) {
      throw FlutterError('QueueSheetHost.of() called with no QueueSheetHost');
    }
    return controller;
  }

  @override
  State<QueueSheetHost> createState() => _QueueSheetHostState();
}

class _QueueSheetScope extends InheritedWidget {
  const _QueueSheetScope({required this.controller, required super.child});

  final QueueSheetController controller;

  // The controller never changes, so nothing depends on it for rebuilds.
  @override
  bool updateShouldNotify(_QueueSheetScope oldWidget) => false;
}

class _QueueSheetHostState extends State<QueueSheetHost>
    with SingleTickerProviderStateMixin
    implements QueueSheetController {
  late final AnimationController _animation;
  late final CurvedAnimation _curved;
  final _focus = FocusScopeNode(debugLabel: 'Queue sheet');

  /// True from when the sheet starts opening until it starts closing.
  bool _open = false;

  /// What had focus before opening, to give it back after closing.
  FocusNode? _previousFocus;

  @override
  bool get isOpen => _open;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this, duration: queueSheetDuration)
      ..addStatusListener(_onStatus);
    _curved = CurvedAnimation(parent: _animation, curve: queueSheetCurve);
  }

  @override
  void dispose() {
    _curved.dispose();
    _animation.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void open() {
    if (_open) return;
    _open = true;
    _previousFocus = FocusManager.instance.primaryFocus;
    widget.onOpenChanged?.call(true);
    setState(() {});
    _move(forward: true);
    // The sheet is built by the next frame; focus can go in after that.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) _focus.requestFocus();
    });
  }

  @override
  void close() {
    if (!_open) return;
    _open = false;
    widget.onOpenChanged?.call(false);
    setState(() {});
    _move(forward: false);
  }

  void _move({required bool forward}) {
    // Reduced motion: appear and disappear at once.
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = forward ? 1 : 0;
    } else {
      forward ? _animation.forward() : _animation.reverse();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || _open) return;
    // Slid out: drop the sheet and hand focus back.
    final previous = _previousFocus;
    _previousFocus = null;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && previous != null && previous.context != null) {
        previous.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showing = _open || !_animation.isDismissed;
    return _QueueSheetScope(
      controller: this,
      child: Listener(
        onPointerDown: _onPointerDown,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (showing) Positioned.fill(child: _buildSheet(context)),
          ],
        ),
      ),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons & kBackMouseButton != 0) {
      _open ? close() : widget.onMouseBack?.call();
    } else if (event.buttons & kForwardMouseButton != 0 && !_open) {
      widget.onMouseForward?.call();
    }
  }

  Widget _buildSheet(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final width = min(queueSheetWidth, MediaQuery.sizeOf(context).width * 0.9);
    // Esc closes the sheet and stops there, so it never reaches the
    // DismissIntent of Now Playing behind it.
    return Actions(
      actions: {
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (_) {
            close();
            return null;
          },
        ),
      },
      child: FocusScope(
        node: _focus,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: close,
                child: FadeTransition(
                  opacity: _curved,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: _scrimAlpha),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: width,
              // Only the position animates: the panel never fades or scales.
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(_curved),
                child: ColoredBox(
                  // Translucent, so the dimmed screen still shows through.
                  color: colors.surface.withValues(alpha: 0.6),
                  child: Material(
                    type: MaterialType.transparency,
                    child: SafeArea(child: QueuePanel(onClose: close)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
