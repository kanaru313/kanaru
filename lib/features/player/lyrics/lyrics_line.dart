import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/lyrics.dart';
import 'lyrics_text_style.dart';

/// How long a line takes to change between current and not.
const _styleDuration = Duration(milliseconds: 200);

/// One line of synced lyrics. Rebuilds only when [current] flips, never on
/// a position tick; pressing it seeks to the line.
class LyricsLine extends StatelessWidget {
  const LyricsLine({
    super.key,
    required this.line,
    required this.current,
    required this.onTap,
  });

  final LyricLine line;
  final ValueListenable<bool> current;
  final VoidCallback onTap;

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
          child: ValueListenableBuilder<bool>(
            valueListenable: current,
            builder: (context, isCurrent, _) => AnimatedDefaultTextStyle(
              style: lyricsLineStyle(context, current: isCurrent),
              duration: reduceMotion ? Duration.zero : _styleDuration,
              curve: Curves.easeOutCubic,
              textAlign: TextAlign.center,
              child: Text(line.text),
            ),
          ),
        ),
      ),
    );
  }
}
