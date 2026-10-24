import 'dart:math';

import 'package:material_ui/material_ui.dart';

/// Height of a queue row: 56 at the default text size, taller when the text
/// scale grows so a title line, an artist line and 16 px of padding still fit.
///
/// The lists give every row this same height, which lets them place and jump
/// to rows without measuring them. Read it where the list is built so it
/// follows the text scale of the window.
double queueRowExtent(BuildContext context) {
  final text = Theme.of(context).textTheme;
  final scaler = MediaQuery.textScalerOf(context);
  double line(TextStyle? style, double size, double height) =>
      scaler.scale(style?.fontSize ?? size) * (style?.height ?? height);
  final lines = line(text.bodyLarge, 16, 1.5) + line(text.bodySmall, 12, 1.34);
  return max(56, lines + 16);
}

/// Height of the Now playing row: a larger cover (56 px) in a row 16 px
/// taller than the others, scaled with the text the same way.
double queueNowPlayingExtent(BuildContext context) =>
    queueRowExtent(context) + 16;

/// Height of a section label and of the Earlier toggle: 40 px at the default
/// text size, taller when the text scale grows so the label line plus its
/// padding still fits.
double queueSectionLabelExtent(BuildContext context) {
  final style = Theme.of(context).textTheme.labelLarge;
  final line =
      MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 14) *
      (style?.height ?? 1.43);
  return max(40, line + 18);
}
