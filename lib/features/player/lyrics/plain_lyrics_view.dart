import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/lyrics.dart';
import 'lyrics_text_style.dart';

/// Unsynchronized lyrics: every line as it is, centered, scrollable, no
/// highlight.
class PlainLyricsView extends StatelessWidget {
  const PlainLyricsView({super.key, required this.lyrics});

  final Lyrics lyrics;

  @override
  Widget build(BuildContext context) {
    final style = lyricsLineStyle(
      context,
      current: true,
    ).copyWith(fontWeight: FontWeight.w400);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: lyricsSidePadding,
        vertical: 48,
      ),
      itemCount: lyrics.lines.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: lyricsLineGap / 2),
        child: Text(
          lyrics.lines[i].text,
          style: style,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
