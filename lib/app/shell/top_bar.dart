import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/player/open_media.dart';
import '../../l10n/l10n.dart';
import 'app_destination.dart';
import 'navigation_history.dart';
import 'top_bar_search_field.dart';
import 'window/desktop_window.dart';
import 'window/window_buttons.dart';
import 'window/window_drag_area.dart';

const topBarHeight = 64.0;

/// Top bar width below which back/forward are hidden, so the search field
/// gets their space. Mouse side buttons still move through the history.
const _historyButtonsMinWidth = 560.0;

/// Header above every page: back/forward, search, open music, settings and,
/// when the app draws its own title bar, the window buttons. Empty space drags the window.
/// On narrow bars back/forward are left out.
class TopBar extends ConsumerWidget {
  const TopBar({super.key, this.onMenuPressed});

  /// Opens the sidebar drawer on narrow windows. `null` hides the button.
  final VoidCallback? onMenuPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final history = ref.watch(navigationHistoryProvider);
    final historyNotifier = ref.read(navigationHistoryProvider.notifier);

    return WindowDragArea(
      child: SizedBox(
        height: topBarHeight,
        child: LayoutBuilder(
          builder: (context, constraints) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              spacing: 8,
              children: [
                if (onMenuPressed != null)
                  WindowDragExclusion(
                    child: IconButton(
                      icon: const Icon(Icons.menu),
                      tooltip: MaterialLocalizations.of(context)
                          .openAppDrawerTooltip,
                      onPressed: onMenuPressed,
                    ),
                  ),
                if (constraints.maxWidth >= _historyButtonsMinWidth) ...[
                  WindowDragExclusion(
                    child: TopBarButton(
                      icon: Icons.chevron_left,
                      tooltip: l10n.topBarBack,
                      onPressed: history.canGoBack
                          ? historyNotifier.back
                          : null,
                    ),
                  ),
                  WindowDragExclusion(
                    child: TopBarButton(
                      icon: Icons.chevron_right,
                      tooltip: l10n.topBarForward,
                      onPressed: history.canGoForward
                          ? historyNotifier.forward
                          : null,
                    ),
                  ),
                ],
                // Takes all free space so the buttons after it stay at the right
                // edge; the field itself never grows past 320.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: WindowDragExclusion(
                        child: const TopBarSearchField(),
                      ),
                    ),
                  ),
                ),
                WindowDragExclusion(
                  child: OpenMediaMenu(
                    builder: (tooltip, onPressed) => TopBarButton(
                      icon: Icons.library_music_outlined,
                      tooltip: tooltip,
                      onPressed: onPressed,
                    ),
                  ),
                ),
                WindowDragExclusion(
                  child: TopBarButton(
                    icon: Icons.settings_outlined,
                    tooltip: l10n.navSettings,
                    onPressed: () => context.go(AppDestination.settings.path),
                  ),
                ),
                if (ref.watch(customTitleBarProvider)) ...[
                  const SizedBox(width: 8),
                  const WindowButtons(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round tonal icon button used across the top bar, so every button there
/// has the same size as the window buttons.
class TopBarButton extends StatelessWidget {
  const TopBarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = 20,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      icon: Icon(icon, size: iconSize),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
    );
  }
}
