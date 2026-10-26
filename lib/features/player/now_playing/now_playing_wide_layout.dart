import 'package:material_ui/material_ui.dart';

import 'now_playing_auto_hide.dart';
import 'now_playing_cover_only_body.dart';
import 'now_playing_header.dart';
import 'now_playing_lyrics_only_body.dart';
import 'now_playing_side_pane.dart';
import 'now_playing_split_geometry.dart';
import 'now_playing_title_bar.dart';
import 'now_playing_track_column.dart';
import 'now_playing_view_mode.dart';

/// How long a switch the user asked for takes to cross-fade.
const nowPlayingModeFadeDuration = Duration(milliseconds: 300);

/// Wide Now Playing: the auto-hiding header over the body of the current
/// view mode. A switch the user asks for cross-fades; one that lyrics
/// appearing or vanishing cause happens at once, as does any under reduced
/// motion.
class NowPlayingWideLayout extends StatefulWidget {
  const NowPlayingWideLayout({
    super.key,
    required this.chrome,
    required this.floatingOpen,
    required this.onClose,
    required this.chosenMode,
    required this.mode,
    required this.lyricsState,
    required this.onChoose,
    this.titleBar,
    this.lyrics,
  });

  final AutoHideController chrome;

  /// See [NowPlayingHeader.floatingOpen].
  final ValueNotifier<bool> floatingOpen;
  final VoidCallback onClose;
  final NowPlayingTitleBar? titleBar;

  /// The mode the user chose, and the one shown ([effectiveViewMode]).
  final NowPlayingViewMode chosenMode;
  final NowPlayingViewMode mode;
  final NowPlayingLyricsState lyricsState;
  final ValueChanged<NowPlayingViewMode> onChoose;

  /// The lyrics view; `null` when the track has none.
  final Widget? lyrics;

  @override
  State<NowPlayingWideLayout> createState() => _NowPlayingWideLayoutState();
}

class _NowPlayingWideLayoutState extends State<NowPlayingWideLayout> {
  /// Changes when lyrics, not the user, switch the body. A switcher's fade
  /// time is fixed when a body enters, so such a switch gets a new switcher
  /// instead, which shows the new body at once.
  int _instantSwitches = 0;

  @override
  void didUpdateWidget(NowPlayingWideLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode != oldWidget.mode &&
        widget.chosenMode == oldWidget.chosenMode) {
      _instantSwitches++;
    }
  }

  Widget _body(BuildContext context, BoxConstraints constraints) {
    final chrome = widget.chrome;
    return switch (widget.mode) {
      NowPlayingViewMode.split => Row(
        key: const ValueKey(NowPlayingViewMode.split),
        children: [
          SizedBox(
            width: splitColumnWidth(constraints.maxWidth),
            child: NowPlayingTrackColumn(chrome: chrome),
          ),
          Expanded(child: NowPlayingSidePane(lyrics: widget.lyrics)),
        ],
      ),
      // Before the first answer the lyrics body shows empty rather than the
      // Cover only fallback, so reopening in Lyrics only does not flash the
      // other body.
      NowPlayingViewMode.lyricsOnly => NowPlayingLyricsOnlyBody(
        key: const ValueKey(NowPlayingViewMode.lyricsOnly),
        lyrics: widget.lyrics ?? const SizedBox.expand(),
        chrome: chrome,
        onShowSplit: () => widget.onChoose(NowPlayingViewMode.split),
      ),
      NowPlayingViewMode.coverOnly => NowPlayingCoverOnlyBody(
        key: const ValueKey(NowPlayingViewMode.coverOnly),
        chrome: chrome,
      ),
    };
  }

  /// Fades [child] in or out. The tree is the same for every child, and only
  /// the flags change: the outgoing body is neither remounted nor reachable
  /// while it fades.
  Widget _transition(Widget child, Animation<double> animation) =>
      FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: animation,
          builder: (_, child) {
            final leaving = animation.status == AnimationStatus.reverse;
            return IgnorePointer(
              ignoring: leaving,
              child: ExcludeFocus(excluding: leaving, child: child!),
            );
          },
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final titleBar = widget.titleBar;
    final header = NowPlayingHeader(
      onClose: widget.onClose,
      excludeFromDrag: titleBar?.excludeFromDrag ?? noDragExclusion,
      floatingOpen: widget.floatingOpen,
      hasWindowButtons: titleBar?.hasWindowButtons ?? false,
      modeButton: NowPlayingViewModeButton(
        mode: widget.mode,
        lyricsState: widget.lyricsState,
        onChoose: widget.onChoose,
      ),
    );
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : nowPlayingModeFadeDuration;
    return AutoHideRegion(
      controller: widget.chrome,
      child: Column(
        children: [
          AutoHide(
            controller: widget.chrome,
            child: titleBar?.wrapHeader(header) ?? header,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => AnimatedSwitcher(
                key: ValueKey((_instantSwitches, duration)),
                duration: duration,
                transitionBuilder: _transition,
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, ?current],
                ),
                child: _body(context, constraints),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
