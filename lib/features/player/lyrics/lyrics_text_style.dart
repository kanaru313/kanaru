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
