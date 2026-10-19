import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import 'now_playing_open_provider.dart';

/// Height of the header strip across the top of Now Playing.
const nowPlayingHeaderHeight = 64.0;

/// The full-window Now Playing page. Its own [Scaffold], a sibling of the
/// shell's rather than nested in it, so snack bars show on top of it.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key, this.titleBar});

  /// See `NowPlayingOverlay.titleBar`.
  final Widget Function(Widget header)? titleBar;

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  final _focus = FocusNode(debugLabel: 'Now Playing');

  @override
  void initState() {
    super.initState();
    // `autofocus` alone loses to whatever the shell still has focused, which
    // is only released once this frame is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _close() => ref.read(nowPlayingOpenProvider.notifier).close();

  @override
  Widget build(BuildContext context) {
    final header = SizedBox(
      height: nowPlayingHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.expand_more),
            tooltip: context.l10n.nowPlayingClose,
            onPressed: _close,
          ),
        ),
      ),
    );
    final titleBar = widget.titleBar;
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
          child: Scaffold(
            body: Column(
              children: [
                titleBar == null ? header : titleBar(header),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
