import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../queue/queue_drawer.dart';
import '../queue/queue_panel.dart';
import 'now_playing_auto_hide.dart';
import 'now_playing_footer.dart';
import 'now_playing_open_provider.dart';
import 'now_playing_tabs.dart';
import 'now_playing_track_info.dart';

/// Window width below which Now Playing becomes one column with tabs.
const _wideBreakpoint = 720.0;

/// The full-window Now Playing page. Its own [Scaffold], a sibling of the
/// shell's rather than nested in it, so snack bars show on top of it.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key, this.titleBar, this.hasLyrics = false});

  /// See `NowPlayingOverlay.titleBar`.
  final Widget Function(Widget header)? titleBar;

  /// Whether lyrics share the page with the cover block (not built yet, so
  /// always `false`): the block then takes half the width.
  final bool hasLyrics;

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  final _focus = FocusNode(debugLabel: 'Now Playing');
  final _chrome = AutoHideController();

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

  Widget _wrapHeader(Widget header) => widget.titleBar?.call(header) ?? header;

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
          child: Scaffold(
            endDrawer: const QueueDrawer(),
            endDrawerEnableOpenDragGesture: false,
            // The chrome stays while the drawer is open.
            onEndDrawerChanged: (open) =>
                open ? _chrome.pin() : _chrome.unpin(),
            body: wide
                ? AutoHideRegion(controller: _chrome, child: _wide())
                : NowPlayingTabs(
                    wrapHeader: _wrapHeader,
                    queuePage: const QueuePanel(),
                    onClose: _close,
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
          child: _wrapHeader(const SizedBox(height: nowPlayingHeaderHeight)),
        ),
        Expanded(child: _WideBody(hasLyrics: widget.hasLyrics)),
        AutoHide(
          controller: _chrome,
          child: NowPlayingFooter(onClose: _close),
        ),
      ],
    );
  }
}

/// Cover block in the middle of the space between header and footer.
class _WideBody extends ConsumerWidget {
  const _WideBody({required this.hasLyrics});

  final bool hasLyrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      playerServiceProvider.select((s) => s.queue.current),
    );
    if (track == null) return const SizedBox.shrink();
    final windowHeight = MediaQuery.sizeOf(context).height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final blockWidth = hasLyrics
            ? constraints.maxWidth / 2
            : constraints.maxWidth;
        // 70% of the block, at most half the window, and leaving room for
        // the title and artist below.
        final art = [
          blockWidth * 0.7,
          windowHeight * 0.5,
          constraints.maxHeight - 140,
        ].reduce((a, b) => a < b ? a : b).clamp(96.0, double.infinity);
        return Row(
          children: [
            SizedBox(
              width: blockWidth,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: NowPlayingTrackInfo(track: track, artworkSize: art),
                ),
              ),
            ),
            if (hasLyrics) const Expanded(child: SizedBox.shrink()),
          ],
        );
      },
    );
  }
}
