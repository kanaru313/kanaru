import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/lyrics.dart';
import '../../../core/settings/translation_prefs.dart';
import 'lyrics_text_style.dart';
import 'translation/translated_line_text.dart';

/// How long a line takes to change between current and not.
const _styleDuration = Duration(milliseconds: 200);

/// One line of synced lyrics. Rebuilds only when [current] flips, never on
/// a position tick; pressing it seeks to the line. Its text has its own
/// repaint boundary, so the view scrolling past, or a neighbour changing
/// style, draws the picture it already has instead of laying the text out
/// and painting it again on every frame.
///
/// With a [translation], or while one is [translationPending], the line also
/// shows it (see [TranslatedLineText]); the added text changes color only
/// when [current] flips.
class LyricsLine extends StatelessWidget {
  const LyricsLine({
    super.key,
    required this.line,
    required this.current,
    required this.onTap,
    this.translation,
    this.translationPending = false,
    this.display = LyricsTranslationDisplay.underLine,
    this.pulse,
    this.translationDirection,
  });

  final LyricLine line;
  final ValueListenable<bool> current;
  final VoidCallback onTap;
  final String? translation;
  final bool translationPending;
  final LyricsTranslationDisplay display;

  /// Opacity of the placeholder bars; `null` keeps them still.
  final Animation<double>? pulse;
  final TextDirection? translationDirection;

  @override
  Widget build(BuildContext context) {
    // A timed blank line is a pause in the singing: a gap, nothing to press.
    if (line.text.isEmpty) return const SizedBox(height: lyricsLineGap * 2);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: lyricsLineGap / 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: RepaintBoundary(
            child: ValueListenableBuilder<bool>(
              valueListenable: current,
              builder: (context, isCurrent, _) => TranslatedLineText(
                original: line.text,
                mainStyle: lyricsLineStyle(context, current: isCurrent),
                current: isCurrent,
                duration: reduceMotion ? Duration.zero : _styleDuration,
                translation: translation,
                pending: translationPending,
                display: display,
                pulse: pulse,
                translationDirection: translationDirection,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
