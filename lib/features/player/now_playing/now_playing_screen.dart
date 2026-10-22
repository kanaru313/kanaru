import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../queue/queue_panel.dart';
import '../queue/queue_sheet_host.dart';
import 'now_playing_auto_hide.dart';
import 'now_playing_cover_gradient.dart';
import 'now_playing_footer.dart';
import 'now_playing_open_provider.dart';
import 'now_playing_title_bar.dart';
import 'now_playing_tabs.dart';
import 'now_playing_wide_body.dart';

/// Window width below which Now Playing becomes one column with tabs.
const _wideBreakpoint = 720.0;

/// The full-window Now Playing page. Its own [Scaffold], a sibling of the
/// shell's rather than nested in it, so snack bars show on top of it.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key, this.titleBar, this.lyrics});

  /// See `NowPlayingOverlay.titleBar`.
  final NowPlayingTitleBar? titleBar;

  /// Lyrics view (none exists yet, so `null`). With it the cover block takes
  /// half the width and the header shows the lyrics-only toggle.
  final Widget? lyrics;

  bool get hasLyrics => lyrics != null;

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  final _focus = FocusNode(debugLabel: 'Now Playing');
  final _chrome = AutoHideController();
  bool _lyricsOnly = false;

  @override
  void initState() {
    super.initState();
    // `autofocus` alone loses to whatever the shell still has focused, which
    // is only released once this frame is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    _chrome.poke();
  }

  @override
  void dispose() {
    _focus.dispose();
    _chrome.dispose();
    super.dispose();
  }

  void _close() => ref.read(nowPlayingOpenProvider.notifier).close();

  NowPlayingDragExclusion get _exclude =>
      widget.titleBar?.excludeFromDrag ?? noDragExclusion;

  Widget _wrapHeader(Widget header) =>
      widget.titleBar?.wrapHeader(header) ?? header;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    // Esc is mapped to DismissIntent by the app; nothing handles it unless a
    // route does, so this is what closes the screen.
    return FocusScope(
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              _close();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focus,
          // Any key brings the hidden header and footer back, so focus is
          // never left on a button nobody can see.
          onKeyEvent: (_, _) {
            _chrome.poke();
            return KeyEventResult.ignored;
          },
          // The chrome stays while the queue sheet is open.
          child: QueueSheetHost(
            onMouseBack: _close,
            onOpenChanged: (open) => open ? _chrome.pin() : _chrome.unpin(),
            // The background is the gradient's, which is always opaque.
            child: NowPlayingCoverGradient(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: wide
                    ? AutoHideRegion(controller: _chrome, child: _wide())
                    : NowPlayingTabs(
                        wrapHeader: _wrapHeader,
                        excludeFromDrag: _exclude,
                        queuePage: const QueuePanel(),
                        onClose: _close,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wide() {
    return Column(
      children: [
        AutoHide(
          controller: _chrome,
          child: _wrapHeader(
            NowPlayingWideHeader(
              height: nowPlayingHeaderHeight,
              excludeFromDrag: _exclude,
              hasLyrics: widget.hasLyrics,
              lyricsOnly: _lyricsOnly,
              onToggleLyricsOnly: () =>
                  setState(() => _lyricsOnly = !_lyricsOnly),
            ),
          ),
        ),
        Expanded(
          child: NowPlayingWideBody(
            lyrics: widget.lyrics,
            lyricsOnly: _lyricsOnly,
          ),
        ),
        AutoHide(
          controller: _chrome,
          child: NowPlayingFooter(
            onClose: _close,
            onVolumePopupChanged: (open) =>
                open ? _chrome.pin() : _chrome.unpin(),
          ),
        ),
      ],
    );
  }
}
