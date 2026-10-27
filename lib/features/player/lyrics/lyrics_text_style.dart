import 'package:material_ui/material_ui.dart';

/// Space between lyric lines.
const lyricsLineGap = 10.0;

/// Side padding of the lyrics column.
const lyricsSidePadding = 32.0;

/// Text style of a lyric line: the current line of synced lyrics stands out
/// in full color and bold, the others are dimmed. Plain lyrics use the
/// current style without the weight.
TextStyle lyricsLineStyle(BuildContext context, {required bool current}) {
  final theme = Theme.of(context);
  final base = theme.textTheme.headlineSmall!;
  return current
      ? base.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        )
      : base.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
        );
}

/// Size of the translation under a line, as a share of the line's size.
const lyricsTranslationScale = 0.62;

/// Size of the small original above a translation that replaces it.
const lyricsSmallOriginalScale = 0.5;

TextStyle _addedStyle(
  BuildContext context, {
  required double scale,
  required bool current,
}) {
  final theme = Theme.of(context);
  final base = theme.textTheme.headlineSmall!;
  // Same weight in both states: only the color changes with [current], so
  // the added text never rewraps when the current line moves.
  return base.copyWith(
    fontSize: base.fontSize! * scale,
    fontWeight: FontWeight.w400,
    color: current
        ? theme.colorScheme.onSurface.withValues(alpha: 0.82)
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.42),
  );
}

/// Style of the translation shown with a line.
TextStyle lyricsTranslationStyle(
  BuildContext context, {
  required bool current,
}) => _addedStyle(context, scale: lyricsTranslationScale, current: current);

/// Style of the original line when its translation is the main line.
TextStyle lyricsSmallOriginalStyle(
  BuildContext context, {
  required bool current,
}) => _addedStyle(context, scale: lyricsSmallOriginalScale, current: current);
