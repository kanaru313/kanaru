import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../queue/queue_panel.dart';
import '../queue/queue_sheet_host.dart';
import '../cover_tint_background.dart';
import 'now_playing_auto_hide.dart';
import 'now_playing_open_provider.dart';
import 'now_playing_title_bar.dart';
import 'now_playing_tabs.dart';
import 'now_playing_wide_layout.dart';

/// Window width below which Now Playing becomes one column with tabs.
const _wideBreakpoint = 720.0;

/// The full-window Now Playing page. Its own [Scaffold], a sibling of the
/// shell's rather than nested in it, so snack bars show on top of it.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key, this.titleBar, this.lyrics});

  /// See `NowPlayingOverlay.titleBar`.
  final NowPlayingTitleBar? titleBar;

  /// Lyrics view, `null` when the track has none. The wide layout shows it
  /// in a tab next to the queue; the narrow layout as a page right of the
  /// track.
  final Widget? lyrics;

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  final _focus = FocusNode(debugLabel: 'Now Playing');
  final _chrome = AutoHideController();

  /// Whether the volume popup or the sleep timer menu is open. They float
  /// outside the header, so the chrome stays shown meanwhile.
  final _floatingOpen = ValueNotifier<bool>(false);

  void _pinForFloating() =>
      _floatingOpen.value ? _chrome.pin() : _chrome.unpin();

  @override
  void initState() {
    super.initState();
    _floatingOpen.addListener(_pinForFloating);
    // `autofocus` alone loses to whatever the shell still has focused, which
    // is only released once this frame is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    _chrome.poke();
  }

  @override
  void dispose() {
    _floatingOpen
      ..removeListener(_pinForFloating)
      ..dispose();
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
          // Any key brings the hidden header back, so focus is
          // never left on a button nobody can see.
          onKeyEvent: (_, _) {
            _chrome.poke();
            return KeyEventResult.ignored;
          },
          // Nothing here opens the queue sheet; the host stays so the mouse
          // back button closes Now Playing.
          child: QueueSheetHost(
            onMouseBack: _close,
            onOpenChanged: (open) => open ? _chrome.pin() : _chrome.unpin(),
            // The background is the gradient's, which is always opaque.
            child: CoverTintBackground(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: wide
                    ? NowPlayingWideLayout(
                        chrome: _chrome,
                        floatingOpen: _floatingOpen,
                        onClose: _close,
                        titleBar: widget.titleBar,
                        lyrics: widget.lyrics,
                      )
                    : NowPlayingTabs(
                        wrapHeader: _wrapHeader,
                        excludeFromDrag: _exclude,
                        queuePage: const QueuePanel(),
                        lyricsPage: widget.lyrics,
                        onClose: _close,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
