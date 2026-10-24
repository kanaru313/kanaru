import 'package:material_ui/material_ui.dart';

/// A strut that holds every line of a text at [style]'s own height (font
/// size times `height`). A fallback font (CJK) has taller glyphs; without it
/// such a line grows past the height a tile or row reserved from the theme.
StrutStyle? fixedLineStrut(TextStyle? style) => style == null
    ? null
    : StrutStyle.fromTextStyle(style, forceStrutHeight: true);
