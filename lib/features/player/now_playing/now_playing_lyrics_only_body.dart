import 'package:material_ui/material_ui.dart';

import 'now_playing_auto_hide.dart';
import 'now_playing_lyrics_strip.dart';

/// Widest the lyrics column gets.
const _lyricsMaxWidth = 800.0;

/// Body of Lyrics only: [lyrics] fill a centered column, and a strip with the
/// playing track and its controls overlays the bottom, shown and hidden with
/// [chrome]. The strip never takes room from the lyrics, so they stay put
/// when it fades.
class NowPlayingLyricsOnlyBody extends StatelessWidget {
  const NowPlayingLyricsOnlyBody({
    super.key,
    required this.lyrics,
    required this.chrome,
    required this.onShowSplit,
  });

  /// The lyrics view; it fills the space it is given.
  final Widget lyrics;
  final AutoHideController chrome;

  /// Called when the cover on the strip is pressed.
  final VoidCallback onShowSplit;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Stack(
      children: [
        Positioned.fill(
          child: MediaQuery(
            // Plain lyrics add the bottom padding to their margin, so their
            // last line can scroll clear of the strip; synced lyrics already
            // pad their end.
            data: media.copyWith(
              padding: media.padding.copyWith(
                bottom: lyricsStripHeight(context),
              ),
            ),
            child: Theme(
              // lyricsLineStyle reads headlineSmall; this override gives every
              // line headlineMedium, so the current line differs from the
              // others by weight and color only. A size change would reflow
              // the column and move the line off its anchor.
              data: theme.copyWith(
                textTheme: textTheme.copyWith(
                  headlineSmall: textTheme.headlineMedium,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _lyricsMaxWidth),
                  child: SizedBox.expand(child: lyrics),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AutoHide(
            controller: chrome,
            child: NowPlayingLyricsStrip(onShowSplit: onShowSplit),
          ),
        ),
      ],
    );
  }
}
