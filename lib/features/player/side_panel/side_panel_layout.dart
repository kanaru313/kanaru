import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/settings/settings_provider.dart';

/// Window width from which the side panel can dock beside the page.
///
/// With the expanded 240 px sidebar and the panel, the page keeps
/// 1360 - 241 - 361 = 758 px: above the compact page header width (640,
/// `pageHeaderCompactWidth`) and the 720 px settings column, so pages keep
/// their wide layouts. 1366 px laptops qualify; the 1280 px default window
/// does not (678 px) and keeps the overlay sheet.
const sidePanelBreakpoint = 1360.0;

/// Width of the docked panel, without its divider.
const sidePanelWidth = 360.0;

/// Whether the window is wide enough for the docked panel. Depends on the
/// window size, so a widget calling it rebuilds when the window is resized.
bool sidePanelAvailable(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= sidePanelBreakpoint;

/// Toggles the docked panel on [tab] for a button of the player bar: closed
/// or showing the other tab opens it on [tab]; showing [tab] closes it.
void toggleSidePanel(WidgetRef ref, SidePanelTab tab) {
  final display = ref.read(settingsProvider).display;
  final showing = display.sidePanelOpen && display.sidePanelTab == tab;
  ref
      .read(settingsProvider.notifier)
      .setDisplay(display.copyWith(sidePanelOpen: !showing, sidePanelTab: tab));
}
