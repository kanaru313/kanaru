import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/settings/settings_provider.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../playback_controls.dart';
import 'side_panel_layout.dart';

/// Player bar button that shows or hides the lyrics in the docked side
/// panel. Only there while the window is wide enough to dock the panel. It
/// never reads the lyrics: the panel does, and only while it shows them.
class LyricsPanelButton extends ConsumerWidget {
  const LyricsPanelButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!sidePanelAvailable(context)) return const SizedBox.shrink();
    final selected = ref.watch(
      settingsProvider.select(
        (s) =>
            s.display.sidePanelOpen &&
            s.display.sidePanelTab == SidePanelTab.lyrics,
      ),
    );
    final l10n = context.l10n;
    final label = selected
        ? l10n.sidePanelHideLyrics
        : l10n.sidePanelShowLyrics;
    // The wrapper replaces the button's own semantics: a tooltip alone gives
    // assistive technology no name.
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      onTap: () => toggleSidePanel(ref, SidePanelTab.lyrics),
      excludeSemantics: true,
      child: IconButton(
        icon: const Icon(AppIcons.lyrics),
        iconSize: playerIconSize,
        isSelected: selected,
        tooltip: label,
        onPressed: () => toggleSidePanel(ref, SidePanelTab.lyrics),
      ),
    );
  }
}
