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
/// host, and the queue panel sliding in from the right edge. The sheet and
/// scrim stop [bottomInset] above the bottom edge, so a player bar there
/// stays visible and clickable. It is not a route, so each host (the app
/// shell, Now Playing) has its own sheet and nothing global tracks it.
///
/// While open, focus moves into the sheet and Tab stays inside; Esc closes
/// it from anywhere in the host, also after a click moved focus to a control
/// outside the sheet. Focus returns to where it was once the sheet has slid
/// away.
class QueueSheetHost extends StatefulWidget {
  const QueueSheetHost({
    super.key,
    required this.child,
    this.bottomInset = 0,
    this.closed = false,
    this.onOpenChanged,
    this.onMouseBack,
    this.onMouseForward,
  });

  final Widget child;

  /// Height at the bottom that the scrim and sheet leave uncovered.
  final double bottomInset;

  /// Closes an open sheet when it turns true; the shell sets it while a
  /// screen covers the host (Now Playing).
  final bool closed;

  /// The mouse back and forward side buttons when the sheet is closed. While
  /// it is open, back closes it (like Esc) and forward does nothing.
  final VoidCallback? onMouseBack;
  final VoidCallback? onMouseForward;

  /// Called when the sheet starts opening (`true`) or closing (`false`).
  final ValueChanged<bool>? onOpenChanged;

  static QueueSheetController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_QueueSheetScope>()?.controller;

  /// Whether the nearest sheet is open (not yet closing), rebuilding the
  /// caller when that changes; `false` without a host.
  static bool isOpenOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_QueueSheetScope>()?.open ??
      false;

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
  const _QueueSheetScope({
    required this.controller,
    required this.open,
    required super.child,
  });

  final QueueSheetController controller;
  final bool open;

  // Only [QueueSheetHost.isOpenOf] depends on the scope; the controller
  // itself never changes, so `maybeOf` and `of` do not.
  @override
  bool updateShouldNotify(_QueueSheetScope oldWidget) => open != oldWidget.open;
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
  void didUpdateWidget(QueueSheetHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.closed && !oldWidget.closed) close();
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
      open: _open,
      child: Listener(
        onPointerDown: _onPointerDown,
        // Esc closes the sheet from anywhere in the host and stops there, so
        // it never reaches the DismissIntent of a Now Playing behind it. The
        // map is empty while closed, so Esc keeps its other meanings. The
        // Actions widget is always built, or the child would remount.
        child: Actions(
          actions: _open
              ? {
                  DismissIntent: CallbackAction<DismissIntent>(
                    onInvoke: (_) {
                      close();
                      return null;
                    },
                  ),
                }
              : const {},
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (showing)
                Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  bottom: widget.bottomInset,
                  child: _buildSheet(context),
                ),
            ],
          ),
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
    return FocusScope(
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
              child: Material(
                color: colors.surfaceContainerLow,
                child: SafeArea(child: QueuePanel(onClose: close)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
