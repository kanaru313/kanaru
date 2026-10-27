import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../playback_controls.dart';
import 'now_playing_view_mode.dart';

/// Cycles the view mode: its icon shows the mode on screen, its tooltip names
/// the one a press switches to.
class NowPlayingViewModeButton extends StatelessWidget {
  const NowPlayingViewModeButton({
    super.key,
    required this.mode,
    required this.lyricsState,
    required this.onChoose,
  });

  /// The mode on screen (the effective one, see [effectiveViewMode]).
  final NowPlayingViewMode mode;
  final NowPlayingLyricsState lyricsState;
  final ValueChanged<NowPlayingViewMode> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final next = nextViewMode(mode, lyricsState);
    return IconButton(
      icon: Icon(switch (mode) {
        NowPlayingViewMode.split => AppIcons.viewSplit,
        NowPlayingViewMode.lyricsOnly => AppIcons.lyrics,
        NowPlayingViewMode.coverOnly => AppIcons.viewCover,
      }),
      iconSize: playerIconSize,
      tooltip: switch (next) {
        NowPlayingViewMode.split => l10n.nowPlayingViewSplit,
        NowPlayingViewMode.lyricsOnly => l10n.nowPlayingLyricsOnly,
        NowPlayingViewMode.coverOnly => l10n.nowPlayingViewCoverOnly,
      },
      onPressed: () => onChoose(next),
    );
  }
}
