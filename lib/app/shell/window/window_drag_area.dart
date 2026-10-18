import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_window.dart';

/// Lets the user move the window by dragging [child] and maximize it with a
/// double click, like a native title bar. Does nothing without a custom
/// title bar.
class WindowDragArea extends ConsumerWidget {
  const WindowDragArea({super.key, required this.child});

  final Widget child;

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(customTitleBarProvider)) return child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: _toggleMaximize,
      child: child,
    );
  }
}
