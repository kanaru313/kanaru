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
      // Room an overlay at the bottom claims through the ambient padding
      // (see the lyrics-only body) comes on top of the usual margin.
      padding: EdgeInsets.fromLTRB(
        lyricsSidePadding,
        48,
        lyricsSidePadding,
        48 + MediaQuery.paddingOf(context).bottom,
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
