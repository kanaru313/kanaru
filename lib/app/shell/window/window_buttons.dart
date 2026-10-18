import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

import '../../../l10n/l10n.dart';
import '../top_bar.dart';

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

  void _toggleMaximize() =>
      _maximized ? windowManager.unmaximize() : windowManager.maximize();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        TopBarButton(
          icon: Icons.remove,
          tooltip: l10n.windowMinimize,
          iconSize: 16,
          onPressed: windowManager.minimize,
        ),
        TopBarButton(
          icon: _maximized ? Icons.filter_none : Icons.crop_square,
          tooltip: _maximized ? l10n.windowRestore : l10n.windowMaximize,
          iconSize: 16,
          onPressed: _toggleMaximize,
        ),
        TopBarButton(
          icon: Icons.close,
          tooltip: l10n.windowClose,
          iconSize: 16,
          onPressed: windowManager.close,
        ),
      ],
    );
  }
}
