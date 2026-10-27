import 'package:material_ui/material_ui.dart';

/// Width of one source character in the bar, in ems of the translation style.
const _emPerCharacter = 0.55;

/// The grey bar that stands where a translation is still coming: one
/// translation line high, about as wide as the line is likely to be. [pulse]
/// drives its opacity; the bar sits in its own repaint boundary so a tick
/// changes a layer's opacity and repaints no text. Without [pulse] (reduced
/// motion, tests) the bar is still.
class LyricsTranslationPlaceholder extends StatelessWidget {
  const LyricsTranslationPlaceholder({
    super.key,
    required this.style,
    required this.sourceLength,
    this.pulse,
  });

  /// The translation style the bar stands in for.
  final TextStyle style;

  /// Characters of the original line.
  final int sourceLength;
  final Animation<double>? pulse;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 14;
    final height = size * (style.height ?? 1);
    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurfaceVariant
            .withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final estimate = _emPerCharacter * size * sourceLength;
          final width = constraints.hasBoundedWidth
              ? estimate.clamp(0.0, constraints.maxWidth)
              : estimate;
          return Center(
            child: SizedBox(
              width: width,
              height: height,
              child: pulse == null
                  ? bar
                  : FadeTransition(opacity: pulse!, child: bar),
            ),
          );
        },
      ),
    );
  }
}
