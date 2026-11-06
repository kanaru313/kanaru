import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics/lyrics.dart';
import '../../../../../core/lyrics/playing_track_lyrics_provider.dart';
import '../../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../../core/player/player_service.dart';
import '../../../../../core/settings/translation_prefs.dart';
import '../../lyrics_text_style.dart';
import '../translated_line_text.dart';

/// Main lyric line font size inside the modal preview card.
const double _previewMainFontSize = 20;

/// Style transition duration for the preview line when animations are enabled.
const Duration _styleTransitionDuration = Duration(milliseconds: 200);

/// Index of the lyric line shown in the preview card: [Lyrics.lineAt] of
/// [position] when [lyrics] are synced; on an empty (instrumental) active
/// line, the nearest previous non-empty line. Before the first line, for plain
/// lyrics, or when no earlier line has text, the first non-empty line.
int previewLineIndex(Lyrics lyrics, Duration position) {
  final raw = lyrics.synced ? lyrics.lineAt(position) : -1;
  for (var i = math.min(raw, lyrics.lines.length - 1); i >= 0; i--) {
    if (lyrics.lines[i].text.trim().isNotEmpty) return i;
  }
  for (var i = 0; i < lyrics.lines.length; i++) {
    if (lyrics.lines[i].text.trim().isNotEmpty) return i;
  }
  return 0;
}

/// Renders the current lyric line and its translation inside the preview card.
///
/// Kept as its own [ConsumerWidget] so playback position ticks only rebuild
/// the preview line when the active line index changes, leaving the rest of
/// the modal untouched.
class TranslationPreviewLine extends ConsumerWidget {
  const TranslationPreviewLine({
    super.key,
    required this.state,
    required this.display,
    required this.showTranslation,
  });

  final LyricsTranslationState state;
  final LyricsTranslationDisplay display;

  /// Whether translation is enabled; when false only the original line shows.
  final bool showTranslation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(playingTrackLyricsProvider).value;
    final lyrics = playing?.lyrics;
    if (lyrics == null || lyrics.lines.isEmpty) {
      return const SizedBox.shrink();
    }
    final index = lyrics.synced
        ? ref.watch(
            playerServiceProvider.select(
              (s) => previewLineIndex(lyrics, s.position),
            ),
          )
        : previewLineIndex(lyrics, Duration.zero);
    final original = lyrics.lines[index].text;

    String? translation;
    TextDirection? direction;
    if (state case TranslationReady(:final lines, :final info)
        when showTranslation) {
      if (index < lines.length) {
        translation = lines[index];
      }
      if (translation != null && translation.isNotEmpty) {
        direction = translationDirectionOf(info.effective.code);
      }
    }

    final theme = Theme.of(context);
    final scaledTheme = theme.copyWith(
      textTheme: theme.textTheme.copyWith(
        headlineSmall: theme.textTheme.headlineSmall?.copyWith(
          fontSize: _previewMainFontSize,
        ),
      ),
    );
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _styleTransitionDuration;

    return Theme(
      data: scaledTheme,
      child: Builder(
        builder: (innerContext) => TranslatedLineText(
          original: original,
          mainStyle: lyricsLineStyle(innerContext, current: true),
          current: true,
          duration: duration,
          translation: translation,
          display: display,
          translationDirection: direction,
        ),
      ),
    );
  }
}
