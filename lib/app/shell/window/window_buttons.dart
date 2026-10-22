import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../top_bar.dart';
import 'desktop_window.dart';
import 'window_drag_area.dart';

/// Minimize, maximize/restore and close buttons for the custom title bar.
class WindowButtons extends StatefulWidget {
  const WindowButtons({super.key});

  @override
  State<WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<WindowButtons> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((value) {
      if (mounted) setState(() => _maximized = value);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return WindowDragExclusion(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          TopBarButton(
            icon: AppIcons.remove,
            tooltip: l10n.windowMinimize,
            iconSize: 16,
            onPressed: windowManager.minimize,
          ),
          TopBarButton(
            icon: _maximized ? AppIcons.windowRestore : AppIcons.windowMaximize,
            tooltip: _maximized ? l10n.windowRestore : l10n.windowMaximize,
            iconSize: 16,
            onPressed: toggleMaximize,
          ),
          TopBarButton(
            icon: AppIcons.close,
            tooltip: l10n.windowClose,
            iconSize: 16,
            onPressed: windowManager.close,
          ),
        ],
      ),
    );
  }
}
