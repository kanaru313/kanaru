import 'package:material_ui/material_ui.dart';

import '../../../../core/settings/translation_prefs.dart';
import '../lyrics_text_style.dart';
import 'lyrics_translation_placeholder.dart';

/// Languages written right to left, as language codes.
const _rtlLanguages = {'ar', 'he', 'fa'};

/// The reading direction of text in [languageCode].
TextDirection translationDirectionOf(String languageCode) =>
    _rtlLanguages.contains(languageCode)
    ? TextDirection.rtl
    : TextDirection.ltr;

/// A lyric line with its translation: the original, and under it the
/// translation or, when it is still coming, a placeholder bar. With
/// [LyricsTranslationDisplay.replace] the translation is the main line and
/// the original a small dim line above it; a line without a translation
/// shows its original as the main line.
///
/// [mainStyle] is the style of the main line. The added text keeps one size
/// and weight in both states and only changes color with [current], so it
/// never changes height when the current line moves. Used by synced and
/// plain lyrics, so the layout is written once.
class TranslatedLineText extends StatelessWidget {
  const TranslatedLineText({
    super.key,
    required this.original,
    required this.mainStyle,
    required this.current,
    required this.duration,
    this.translation,
    this.pending = false,
    this.display = LyricsTranslationDisplay.underLine,
    this.pulse,
    this.translationDirection,
  });

  final String original;
  final TextStyle mainStyle;

  /// Whether the line is the current one; colors the added text.
  final bool current;

  /// How long a style change takes.
  final Duration duration;

  /// The translation of [original], or `null` for none.
  final String? translation;

  /// The translation is on its way: show a placeholder under the original.
  final bool pending;
  final LyricsTranslationDisplay display;
  final Animation<double>? pulse;

  /// Direction of the translation text (right to left for Arabic and so on).
  final TextDirection? translationDirection;

  Widget _text(String text, TextStyle style, {TextDirection? direction}) =>
      AnimatedDefaultTextStyle(
        style: style,
        duration: duration,
        curve: Curves.easeOutCubic,
        textAlign: TextAlign.center,
        child: Text(text, textDirection: direction),
      );

  @override
  Widget build(BuildContext context) {
    final translated = translation != null && translation!.isNotEmpty;
    // A blank line has nothing to translate, so no bar either.
    final waiting = pending && original.trim().isNotEmpty;
    if (!translated && !waiting) return _text(original, mainStyle);

    final addedStyle = lyricsTranslationStyle(context, current: current);
    final replace = display == LyricsTranslationDisplay.replace && translated;
    final children = <Widget>[
      if (replace) ...[
        _text(original, lyricsSmallOriginalStyle(context, current: current)),
        _text(translation!, mainStyle, direction: translationDirection),
      ] else ...[
        _text(original, mainStyle),
        if (translated)
          _text(translation!, addedStyle, direction: translationDirection)
        else
          LyricsTranslationPlaceholder(
            style: addedStyle,
            sourceLength: original.characters.length,
            pulse: pulse,
          ),
      ],
    ];
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    if (!translated) return column;
    return Semantics(
      label: '$original, $translation',
      excludeSemantics: true,
      child: column,
    );
  }
}
