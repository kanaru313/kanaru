import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/settings/settings_provider.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../now_playing/now_playing_open_provider.dart';
import '../playback_controls.dart';
import '../queue/queue_panel.dart';
import 'side_panel_lyrics.dart';

/// The docked side panel: tabs for the play queue ("Now playing") and the
/// lyrics, and a close button. The shell places it right of the page; which
/// tab shows is remembered in the display settings.
class PlayerSidePanel extends ConsumerStatefulWidget {
  const PlayerSidePanel({super.key});

  @override
  ConsumerState<PlayerSidePanel> createState() => _PlayerSidePanelState();
}

class _PlayerSidePanelState extends ConsumerState<PlayerSidePanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  /// Stands for the whole panel: it has focus while any control inside has.
  final _focus = FocusNode(
    debugLabel: 'side panel',
    skipTraversal: true,
    canRequestFocus: false,
  );

  /// What had the keyboard focus before it entered the panel, to hand it
  /// back when the panel is closed from the keyboard.
  FocusNode? _focusBefore;

  /// Whether the user last acted in the panel: a pointer press inside it, or
  /// the keyboard focus moving in. A press elsewhere or the focus leaving
  /// ends it. The queue's `Ctrl+F` follows this.
  var _active = false;

  @override
  void initState() {
    super.initState();
    final tab = ref.read(settingsProvider).display.sidePanelTab;
    _tabs = TabController(length: SidePanelTab.values.length, vsync: this)
      ..index = tab.index;
    FocusManager.instance.addListener(_rememberFocusBefore);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    FocusManager.instance.removeListener(_rememberFocusBefore);
    _focus.dispose();
    _tabs.dispose();
    super.dispose();
  }

  /// Runs on every focus change. Keeps the last focused node outside the
  /// panel (so when the focus enters it, the node it came from is already
  /// stored), and ends [_active] when the focus moves to a node outside:
  /// a pointer press inside only counts until the focus goes elsewhere.
  void _rememberFocusBefore() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) {
      _active = false;
      return;
    }
    if (_focus.hasFocus) return;
    _focusBefore = primary;
    _active = false;
  }

  /// A press counts as inside when the panel itself is on the hit path, so
  /// a menu, dialog or the queue sheet drawn over the panel does not. Presses
  /// are ignored while Now Playing is open: the shell stays built under it.
  void _onPointer(PointerEvent event) {
    if (event is! PointerDownEvent) return;
    if (ref.read(nowPlayingOpenProvider)) {
      _active = false;
      return;
    }
    final box = context.findRenderObject();
    if (box == null || !box.attached) return;
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);
    _active = result.path.any((entry) => identical(entry.target, box));
  }

  void _close() {
    // Only a focus that is inside the panel moves back; a panel restored at
    // startup and closed with the mouse leaves the focus alone.
    final before = _focusBefore;
    final restore =
        _focus.hasFocus && before != null && before.context?.mounted == true;
    _setDisplay((d) => d.copyWith(sidePanelOpen: false));
    if (restore) before.requestFocus();
  }

  void _setDisplay(DisplayPrefs Function(DisplayPrefs) change) {
    final settings = ref.read(settingsProvider.notifier);
    settings.setDisplay(change(ref.read(settingsProvider).display));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final tab = ref.watch(
      settingsProvider.select((s) => s.display.sidePanelTab),
    );
    // The tab changed elsewhere (the bar's buttons): the indicator follows.
    // Settings are written only from a tab press, never from the controller.
    ref.listen(settingsProvider.select((s) => s.display.sidePanelTab), (
      _,
      next,
    ) {
      if (_tabs.index != next.index) _tabs.animateTo(next.index);
    });
    return Focus(
      focusNode: _focus,
      onFocusChange: (has) => _active = has,
      child: Material(
        color: colors.surfaceContainerLow,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TabBar.secondary(
                    controller: _tabs,
                    onTap: (index) => _setDisplay(
                      (d) =>
                          d.copyWith(sidePanelTab: SidePanelTab.values[index]),
                    ),
                    tabs: [
                      Tab(text: l10n.nowPlayingTabQueue),
                      Tab(text: l10n.lyricsTab),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Semantics(
                    label: l10n.sidePanelClose,
                    button: true,
                    onTap: _close,
                    excludeSemantics: true,
                    child: IconButton(
                      icon: const Icon(AppIcons.closeRounded),
                      iconSize: playerIconSize,
                      tooltip: l10n.sidePanelClose,
                      onPressed: _close,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: switch (tab) {
                SidePanelTab.queue => QueuePanel(
                  docked: true,
                  isActive: () => _active,
                ),
                SidePanelTab.lyrics => const SidePanelLyrics(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
