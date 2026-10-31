import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// Length of the soft edge, in logical pixels.
const double fadeEdgeExtent = 28;

/// Gradient that hides [extent] pixels at the start and/or end of a strip
/// [length] long. Stops are fractions of [length].
LinearGradient fadeEdgeGradient({
  required bool fadeStart,
  required bool fadeEnd,
  required double length,
  double extent = fadeEdgeExtent,
  Axis axis = Axis.vertical,
}) {
  final f = length <= 0 ? 0.0 : (extent / length).clamp(0.0, 0.5);
  const clear = Color(0x00FFFFFF);
  const solid = Color(0xFFFFFFFF);
  return LinearGradient(
    begin: axis == Axis.vertical ? Alignment.topCenter : Alignment.centerLeft,
    end: axis == Axis.vertical ? Alignment.bottomCenter : Alignment.centerRight,
    colors: [if (fadeStart) clear, solid, solid, if (fadeEnd) clear],
    stops: [
      if (fadeStart) 0,
      fadeStart ? f : 0,
      fadeEnd ? 1 - f : 1,
      if (fadeEnd) 1,
    ],
  );
}

/// Wraps a scrollable and fades the edge that has more content beyond it.
/// No mask at all while everything fits, so a short list stays crisp.
///
/// [builder] gets the controller to give the scrollable. The scrollable's
/// state survives the mask appearing and disappearing.
class FadeEdgeScrollView extends StatefulWidget {
  const FadeEdgeScrollView({
    super.key,
    required this.builder,
    this.axis = Axis.vertical,
    this.controller,
  });

  final Widget Function(ScrollController controller) builder;
  final Axis axis;

  /// Optional controller owned by the caller.
  final ScrollController? controller;

  @override
  State<FadeEdgeScrollView> createState() => _FadeEdgeScrollViewState();
}

class _FadeEdgeScrollViewState extends State<FadeEdgeScrollView> {
  final _childKey = GlobalKey();
  ScrollController? _own;
  bool _fadeStart = false;
  bool _fadeEnd = false;

  ScrollController get _controller =>
      widget.controller ?? (_own ??= ScrollController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  // Notifications from a scrollable nested in the child (chips inside a
  // list) bubble up here too, so the metrics come from this view's own
  // controller, never from the notification.
  bool _onMetrics() {
    final c = _controller;
    if (!c.hasClients) return false;
    final m = c.position;
    if (m.axis != widget.axis) return false;
    final start = m.pixels > m.minScrollExtent + 0.5;
    final end = m.pixels < m.maxScrollExtent - 0.5;
    if (start == _fadeStart && end == _fadeEnd) return false;
    // Metrics arrive during layout, so the rebuild waits for the next frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _fadeStart = start;
        _fadeEnd = end;
      });
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final child = KeyedSubtree(
      key: _childKey,
      child: widget.builder(_controller),
    );
    final Widget masked = (!_fadeStart && !_fadeEnd)
        ? child
        : ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => fadeEdgeGradient(
              fadeStart: _fadeStart,
              fadeEnd: _fadeEnd,
              axis: widget.axis,
              length: widget.axis == Axis.vertical
                  ? bounds.height
                  : bounds.width,
            ).createShader(bounds),
            child: child,
          );
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onMetrics(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _onMetrics(),
        child: masked,
      ),
    );
  }
}
