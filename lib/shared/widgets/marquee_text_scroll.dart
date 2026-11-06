part of 'marquee_text.dart';

/// Horizontal edge-fade gradient for a marquee box of [width] logical pixels.
/// Always fades the right edge over [_trailingGap] pixels; also fades the left
/// edge over [_trailingGap] pixels while [fadeLeft] is true.
LinearGradient _marqueeGradient({
  required double width,
  required bool fadeLeft,
}) {
  final edge = width <= 0 ? 0.0 : (_trailingGap / width).clamp(0.0, 0.5);
  return LinearGradient(
    colors: [
      if (fadeLeft) Colors.transparent,
      Colors.black,
      Colors.black,
      Colors.transparent,
    ],
    stops: [
      if (fadeLeft) 0,
      fadeLeft ? edge : 0,
      (1 - _trailingGap / width).clamp(fadeLeft ? edge : 0.0, 1.0),
      1,
    ],
  );
}

/// The clipped, faded, scrolling form. Owns the ticker, so a label whose text
/// fits (or that has animations disabled) never creates one.
class _ScrollingText extends StatefulWidget {
  const _ScrollingText({
    required this.text,
    required this.style,
    required this.active,
    required this.startDelay,
    required this.boxWidth,
    required this.boxHeight,
    required this.shift,
  });

  final String text;
  final TextStyle? style;
  final bool active;
  final Duration startDelay;
  final double boxWidth;
  final double boxHeight;
  final double shift;

  @override
  State<_ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<_ScrollingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycle,
  );
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.15, 0.85, curve: Curves.easeInOut),
  );
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    if (widget.active) _scheduleStart();
  }

  @override
  void didUpdateWidget(_ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final restart =
        widget.active &&
        (widget.text != oldWidget.text ||
            widget.shift != oldWidget.shift ||
            widget.startDelay != oldWidget.startDelay);
    if (widget.active == oldWidget.active && !restart) return;
    if (restart) {
      _stop();
      _scheduleStart();
    } else if (widget.active) {
      _scheduleStart();
    } else {
      _stop();
    }
  }

  void _scheduleStart() {
    _delay?.cancel();
    _delay = Timer(widget.startDelay, () {
      _delay = null;
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  void _stop() {
    _delay?.cancel();
    _delay = null;
    _controller.stop();
    _controller.value = 0;
  }

  @override
  void dispose() {
    _delay?.cancel();
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, child) {
          final fadeLeft = _progress.value > 0;
          return ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => _marqueeGradient(
              width: bounds.width,
              fadeLeft: fadeLeft,
            ).createShader(bounds),
            child: SizedBox(
              width: widget.boxWidth,
              height: widget.boxHeight,
              child: OverflowBox(
                minWidth: 0,
                maxWidth: double.infinity,
                alignment: AlignmentDirectional.centerStart,
                child: Transform.translate(
                  offset: Offset(-widget.shift * _progress.value, 0),
                  child: child,
                ),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.only(right: _trailingGap),
          child: Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}
