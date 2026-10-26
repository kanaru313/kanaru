import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Share of the body that the track column takes.
const _columnShare = 0.42;
const _columnMinWidth = 300.0;
const _columnMaxWidth = 600.0;

/// Air left and right of the track column's content, and above and below it.
const splitColumnPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 16);

/// The cover is never larger than this, however much room there is.
const _coverMaxSide = 500.0;
const _coverMinSide = 96.0;

/// Gaps between the cover, the text, the seek slot and the transport row.
const splitCoverGap = 24.0;
const splitSeekGap = 16.0;
const splitTransportGap = 8.0;

/// Gap above the artist and the album line (the album line carries its own).
const _lineGap = 8.0;

/// A line of the artist or album: text, or the 20 px icon beside it.
const _lineIconSize = 20.0;

/// Height of the transport row: the play button, a 36 px icon in a 8 px
/// padding.
const splitTransportHeight = 52.0;

/// Width of the track column inside a body [bodyWidth] wide.
double splitColumnWidth(double bodyWidth) =>
    (bodyWidth * _columnShare).clamp(_columnMinWidth, _columnMaxWidth);

/// Height of [lines] lines of [style] under the ambient text scale.
double nowPlayingTextHeight(
  BuildContext context,
  TextStyle? style,
  int lines, {
  double fallbackSize = 14,
}) {
  final size = style?.fontSize ?? fallbackSize;
  // Flutter's default line height when the style sets none. The text engine
  // rounds each line up to a whole pixel, so the estimate does too.
  final line =
      (MediaQuery.textScalerOf(context).scale(size) * (style?.height ?? 1.2))
          .ceilToDouble();
  return line * lines;
}

/// Height the text under the cover always takes: two title lines, an artist
/// line and an album line, whether or not the song has them. Reserved so the
/// cover and the controls stay where they are when a title wraps or the
/// album arrives late.
double splitTextReserve(
  BuildContext context, {
  required TextStyle? titleStyle,
}) {
  final textTheme = Theme.of(context).textTheme;
  final lineHeight = math.max(
    _lineIconSize,
    nowPlayingTextHeight(context, textTheme.bodyLarge, 1, fallbackSize: 16),
  );
  return nowPlayingTextHeight(context, titleStyle, 2, fallbackSize: 26) +
      _lineGap +
      lineHeight +
      _lineGap +
      lineHeight;
}

/// Everything under the cover that has a fixed height; [seekHeight] is the
/// seek slot's.
double splitReserve(
  BuildContext context, {
  required TextStyle? titleStyle,
  required double seekHeight,
}) {
  return splitCoverGap +
      splitTextReserve(context, titleStyle: titleStyle) +
      splitSeekGap +
      seekHeight +
      splitTransportGap +
      splitTransportHeight;
}

/// Side of the cover for a column [innerWidth] wide in a body
/// [bodyHeight] high. It comes from the fixed reserve, never from what the
/// text happens to leave.
double splitCoverSide(
  BuildContext context, {
  required double innerWidth,
  required double bodyHeight,
  required TextStyle? titleStyle,
  required double seekHeight,
}) {
  final byHeight =
      bodyHeight -
      splitReserve(context, titleStyle: titleStyle, seekHeight: seekHeight) -
      splitColumnPadding.vertical;
  return math
      .min(math.min(innerWidth, _coverMaxSide), byHeight)
      .clamp(_coverMinSide, double.infinity);
}
