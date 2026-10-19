import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'now_playing_open_provider.dart';
import 'now_playing_screen.dart';

/// Slide duration and curve of Now Playing coming up from the bottom edge.
const nowPlayingSlideDuration = Duration(milliseconds: 500);
const nowPlayingSlideCurve = Cubic(0.65, 0.05, 0.36, 1);

/// Puts [NowPlayingScreen] over the whole window while it is open. The screen
/// is built only while open or sliding out, never kept hidden: a hidden
/// subtree would keep its tickers and per-tick rebuilds running. A new screen
/// per opening also means it always takes focus, which Esc relies on.
class NowPlayingOverlay extends ConsumerStatefulWidget {
  const NowPlayingOverlay({super.key, this.titleBar});

  /// Wraps the screen's header, to add the window drag area and buttons that
  /// live in the app shell.
  final Widget Function(Widget header)? titleBar;

  @override
  ConsumerState<NowPlayingOverlay> createState() => _NowPlayingOverlayState();
}

class _NowPlayingOverlayState extends ConsumerState<NowPlayingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  /// What had focus before opening, to give focus back when it closes.
  FocusNode? _previousFocus;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: nowPlayingSlideDuration,
    )..addStatusListener(_onStatus);
    _slide = Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: nowPlayingSlideCurve),
    );
    if (ref.read(nowPlayingOpenProvider)) _controller.value = 1;
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed) return;
    // The screen leaves the tree now; hand focus back to the shell.
    final previous = _previousFocus;
    _previousFocus = null;
    if (previous != null && previous.context != null) previous.requestFocus();
    setState(() {});
  }

  void _onOpenChanged(bool open) {
    if (open) {
      _previousFocus ??= FocusManager.instance.primaryFocus;
      _animate(forward: true);
    } else {
      _animate(forward: false);
    }
  }

  void _animate({required bool forward}) {
    // Reduced motion: appear and disappear at once.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = forward ? 1 : 0;
      setState(() {});
      return;
    }
    forward ? _controller.forward() : _controller.reverse();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nowPlayingOpenProvider, (_, open) => _onOpenChanged(open));
    final open = ref.watch(nowPlayingOpenProvider);
    if (!open && _controller.isDismissed) return const SizedBox.shrink();
    return SlideTransition(
      position: _slide,
      // Opaque to pointers, so nothing reaches the shell underneath.
      child: Listener(
        behavior: HitTestBehavior.opaque,
        child: NowPlayingScreen(titleBar: widget.titleBar),
      ),
    );
  }
}
