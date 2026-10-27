import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/lyrics.dart';
import '../../../core/settings/translation_prefs.dart';
import 'lyrics_text_style.dart';
import 'translation/translated_line_text.dart';

/// Unsynchronized lyrics: every line as it is, centered, scrollable, no
/// highlight. Translations, or placeholders while they come, sit with each
/// line as in synced lyrics, all in the current-line colors.
class PlainLyricsView extends StatelessWidget {
  const PlainLyricsView({
    super.key,
    required this.lyrics,
    this.translations,
    this.translationPending = false,
    this.display = LyricsTranslationDisplay.underLine,
    this.pulse,
    this.translationDirection,
  });

  final Lyrics lyrics;

  /// One entry per line (`null`: none to show), or `null` for no translation.
  final List<String?>? translations;
  final bool translationPending;
  final LyricsTranslationDisplay display;
  final Animation<double>? pulse;
  final TextDirection? translationDirection;

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
        child: TranslatedLineText(
          original: lyrics.lines[i].text,
          mainStyle: style,
          current: true,
          duration: Duration.zero,
          translation: translations != null && i < translations!.length
              ? translations![i]
              : null,
          pending: translationPending,
          display: display,
          pulse: pulse,
          translationDirection: translationDirection,
        ),
      ),
    );
  }
}
