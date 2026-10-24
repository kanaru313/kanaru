import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../playback_controls.dart';
import '../side_panel/side_panel_layout.dart';
import 'queue_sheet_host.dart';

/// Largest count the badge shows; more reads as `9999+`.
const _badgeMax = 9999;

/// Queue icon with the number of tracks queued. Toggles the queue sheet of
/// the nearest [QueueSheetHost]: opens it, or closes it while it is open.
/// With [docks], on a window wide enough for the docked side panel it shows
/// or hides the panel on its queue tab instead of opening the sheet.
class QueueButton extends ConsumerWidget {
  const QueueButton({super.key, this.onPressed, this.docks = false});

  /// Replaces opening the sheet, e.g. to switch to a queue page instead.
  final VoidCallback? onPressed;

  /// Whether the button drives the docked side panel when it can dock. Only
  /// the player bar sets it; Now Playing's buttons keep the sheet.
  final bool docks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      playerServiceProvider.select((s) => s.queue.order.length),
    );
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final sheetOpen = QueueSheetHost.isOpenOf(context);
    final docked = docks && sidePanelAvailable(context);
    // Never selected for a panel that is hidden because the window is narrow.
    final panelOnQueue =
        docked &&
        ref.watch(
          settingsProvider.select(
            (s) =>
                s.display.sidePanelOpen &&
                s.display.sidePanelTab == SidePanelTab.queue,
          ),
        );
    final open = sheetOpen || panelOnQueue;
    return Badge(
      backgroundColor: colors.secondaryContainer,
      textColor: colors.onSecondaryContainer,
      isLabelVisible: count > 0,
      label: Text(count > _badgeMax ? '$_badgeMax+' : '$count'),
      child: IconButton(
        icon: const Icon(AppIcons.queue),
        iconSize: playerIconSize,
        isSelected: open,
        tooltip: open ? l10n.queueClose : l10n.queueOpen,
        onPressed: count == 0 && !open
            ? null
            : onPressed ?? _toggle(context, ref, docked),
      ),
    );
  }

  /// Closes the open sheet; else toggles the docked panel when [docked];
  /// else opens the sheet.
  VoidCallback _toggle(BuildContext context, WidgetRef ref, bool docked) => () {
    final sheet = QueueSheetHost.of(context);
    if (sheet.isOpen) {
      sheet.close();
    } else if (docked) {
      toggleSidePanel(ref, SidePanelTab.queue);
    } else {
      sheet.open();
    }
  };
}
