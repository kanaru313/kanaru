import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/lyrics.dart';
import '../../../core/player/player_service.dart';
import '../../../core/settings/translation_prefs.dart';
import 'lyrics_line.dart';
import 'lyrics_text_style.dart';
import 'synced_lyrics_scroll.dart';

export 'synced_lyrics_scroll.dart' show lyricsAnchor, lyricsManualScrollPause;

/// Synced lyrics that follow playback, centered: the current line is
/// highlighted and kept at [lyricsAnchor]; scrolling by hand pauses that
/// for [lyricsManualScrollPause]; pressing a line seeks to it.
///
/// Position ticks cost one binary search: only a change of the current line
/// flips two per-line notifiers, so two lines rebuild and nothing else.
/// Every line is built (a column, lyrics are short and capped), so any line
/// can be scrolled to. Only this view's own scroll position moves, never an
/// enclosing one such as the narrow layout's page view.
///
/// Translations (one entry per line, `null` for none) show with each line;
/// when they, [display] or [translationPending] really change, the current
/// line is put back at the anchor without a glide, because lines may have
/// grown. An identical rebuild changes nothing.
class SyncedLyricsView extends ConsumerStatefulWidget {
  const SyncedLyricsView({
    super.key,
    required this.lyrics,
    this.translations,
    this.translationPending = false,
    this.display = LyricsTranslationDisplay.underLine,
    this.pulse,
    this.translationDirection,
  });

  final Lyrics lyrics;
  final List<String?>? translations;
  final bool translationPending;
  final LyricsTranslationDisplay display;
  final Animation<double>? pulse;
  final TextDirection? translationDirection;

  @override
  ConsumerState<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends ConsumerState<SyncedLyricsView>
    with SyncedLyricsScroll<SyncedLyricsView> {
  late final List<ValueNotifier<bool>> _current;

  @override
  void initState() {
    super.initState();
    final count = widget.lyrics.lines.length;
    lineKeys = List.generate(count, (_) => GlobalKey());
    _current = List.generate(count, (_) => ValueNotifier(false));
    _setIndex(widget.lyrics.lineAt(ref.read(playerServiceProvider).position));
  }

  @override
  void didUpdateWidget(SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.translations, widget.translations) ||
        oldWidget.display != widget.display ||
        oldWidget.translationPending != widget.translationPending) {
      revealAfterLayout();
    }
  }

  @override
  void dispose() {
    disposeScroll();
    for (final notifier in _current) {
      notifier.dispose();
    }
    super.dispose();
  }

  void _setIndex(int index) {
    if (lineIndex >= 0) _current[lineIndex].value = false;
    lineIndex = index;
    if (index >= 0) _current[index].value = true;
  }

  void _onLineChanged(int index) {
    if (index == lineIndex) return;
    _setIndex(index);
    if (resume == null) reveal(animate: true);
  }

  void _seek(int index) {
    resume?.cancel();
    resume = null;
    final before = lineIndex;
    ref
        .read(playerServiceProvider.notifier)
        .seek(widget.lyrics.lines[index].time);
    // Seeking moves the position at once, which moves the current line and
    // scrolls; a press on the current line only brings it back.
    if (lineIndex == before) reveal(animate: true);
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = widget.lyrics;
    final translations = widget.translations;
    ref.listen(
      playerServiceProvider.select((s) => lyrics.lineAt(s.position)),
      (_, index) => _onLineChanged(index),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        onViewportHeight(height);
        return NotificationListener<ScrollUpdateNotification>(
          onNotification: onScrollUpdate,
          // Desktop platforms give every scrollable a scrollbar that fades in
          // and out on each scroll. Auto-scroll would flash it at every line
          // change: about 20 more frames each, more than the glide itself. So
          // the lyrics scroll without one; wheel, touch and trackpad drag still work.
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context)
                .copyWith(scrollbars: false),
            child: SingleChildScrollView(
              controller: scroll,
              // Room above and below so the first and last lines can reach
              // the anchor.
              padding: EdgeInsets.fromLTRB(
                lyricsSidePadding - 12,
                height * lyricsAnchor,
                lyricsSidePadding - 12,
                height * (1 - lyricsAnchor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < lyrics.lines.length; i++)
                    LyricsLine(
                      key: lineKeys[i],
                      line: lyrics.lines[i],
                      current: _current[i],
                      onTap: () => _seek(i),
                      translation:
                          translations != null && i < translations.length
                          ? translations[i]
                          : null,
                      translationPending: widget.translationPending,
                      display: widget.display,
                      pulse: widget.pulse,
                      translationDirection: widget.translationDirection,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
