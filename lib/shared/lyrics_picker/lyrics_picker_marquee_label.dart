import 'dart:async';

import 'package:flutter/material.dart';

/// Gap kept after the last glyph, and the fixed width of the right-edge fade,
/// so the last glyph ends exactly where the fade begins.
const double _trailingGap = 20;

/// Pause before the scroll starts once the label becomes active.
const Duration _startDelay = Duration(seconds: 1);

/// Duration of one way of the back-and-forth scroll, including the hold at
/// each end.
const Duration _cycle = Duration(seconds: 6);

/// A one-line label that shows a long text in full by scrolling it.
///
/// - Text that fits is a plain [Text]: no fade, no animation.
/// - Text that overflows is clipped with a fade of fixed width (20 px) on the right edge. While
///   [active] is true it scrolls back and forth (after a 1 s pause), holding at
///   both ends; when [active] turns false it returns to the start and stops.
/// - When animations are disabled (`MediaQuery.disableAnimationsOf`), an
///   overflowing text is a static single-line ellipsis and never moves.
///
/// The widget only obeys [active]; the caller decides when that is (hover or
/// keyboard focus). Left-to-right layout only: the fade and the scroll direction
/// do not follow `Directionality`.
class LyricsPickerMarqueeLabel extends StatelessWidget {
  const LyricsPickerMarqueeLabel({
    required this.text,
    required this.active,
    this.style,
    super.key,
  });

  final String text;
  final TextStyle? style;

  /// Whether the label may scroll. Has no effect while the text fits.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final defaults = DefaultTextStyle.of(context);
    var effectiveStyle = defaults.style.merge(style);
    if (MediaQuery.boldTextOf(context)) {
      effectiveStyle = effectiveStyle.merge(
        const TextStyle(fontWeight: FontWeight.bold),
      );
    }
    final locale = Localizations.maybeLocaleOf(context);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final noAnimation = MediaQuery.disableAnimationsOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: effectiveStyle),
          textDirection: direction,
          textScaler: scaler,
          locale: locale,
          maxLines: 1,
          textHeightBehavior: defaults.textHeightBehavior,
          textWidthBasis: defaults.textWidthBasis,
        )..layout();
        final textWidth = painter.width;
        final textHeight = painter.height;
        painter.dispose();

        final boxWidth = constraints.maxWidth;
        if (!boxWidth.isFinite || textWidth <= boxWidth) {
          return Text(text, style: style, maxLines: 1, softWrap: false);
        }
        if (noAnimation) {
          return Text(
            text,
            style: style,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          );
        }
        return _ScrollingText(
          text: text,
          style: style,
          active: active,
          boxWidth: boxWidth,
          boxHeight: textHeight,
          shift: textWidth + _trailingGap - boxWidth,
        );
      },
    );
  }
}

/// The clipped, faded, scrolling form. Owns the ticker, so a label whose text
/// fits (or that has animations disabled) never creates one.
class _ScrollingText extends StatefulWidget {
  const _ScrollingText({
    required this.text,
    required this.style,
    required this.active,
    required this.boxWidth,
    required this.boxHeight,
    required this.shift,
  });

  final String text;
  final TextStyle? style;
  final bool active;
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
        (widget.text != oldWidget.text || widget.shift != oldWidget.shift);
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
    _delay = Timer(_startDelay, () {
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
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => LinearGradient(
          colors: const [Colors.black, Colors.black, Colors.transparent],
          stops: [0, (1 - _trailingGap / bounds.width).clamp(0.0, 1.0), 1],
        ).createShader(bounds),
        child: SizedBox(
          width: widget.boxWidth,
          height: widget.boxHeight,
          child: OverflowBox(
            minWidth: 0,
            maxWidth: double.infinity,
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedBuilder(
              animation: _progress,
              builder: (context, child) => Transform.translate(
                offset: Offset(-widget.shift * _progress.value, 0),
                child: child,
              ),
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
          ),
        ),
      ),
    );
  }
}
