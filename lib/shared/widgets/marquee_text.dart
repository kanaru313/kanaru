import 'dart:async';

import 'package:material_ui/material_ui.dart';

part 'marquee_text_scroll.dart';

/// Gap kept after the last glyph, and the fixed width of the edge fade,
/// so the last glyph ends exactly where the right fade begins.
const double _trailingGap = 20;

/// Default pause before the scroll starts once the label becomes active.
const Duration _defaultStartDelay = Duration(seconds: 1);

/// Duration of one way of the back-and-forth scroll, including the hold at
/// each end.
const Duration _cycle = Duration(seconds: 6);

/// A one-line label that shows a long text in full by scrolling it.
///
/// - Text that fits is a plain [Text]: no fade, no animation.
/// - Text that overflows is clipped with a fade of fixed width (20 px) on the
///   right edge, and also on the left edge once it has scrolled away from the
///   start. While [active] is true it scrolls back and forth (after
///   [startDelay]), holding at both ends; when [active] turns false it returns
///   to the start and stops.
/// - When animations are disabled (`MediaQuery.disableAnimationsOf`), an
///   overflowing text is a static single-line ellipsis and never moves.
///
/// Left-to-right layout only: the fade and the scroll direction do not follow
/// `Directionality`.
class MarqueeText extends StatelessWidget {
  const MarqueeText({
    required this.text,
    this.active = true,
    this.startDelay = _defaultStartDelay,
    this.style,
    super.key,
  });

  final String text;
  final TextStyle? style;

  /// Whether the label may scroll. Has no effect while the text fits.
  final bool active;

  /// Pause before the scroll starts once the label becomes active.
  final Duration startDelay;

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
          startDelay: startDelay,
          boxWidth: boxWidth,
          boxHeight: textHeight,
          shift: textWidth + _trailingGap - boxWidth,
        );
      },
    );
  }
}
