import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/player_service.dart';
import '../../l10n/l10n.dart';
import 'playback_controls.dart';

/// Volume step for one scroll notch.
const _scrollStep = 5.0;

/// Click mutes/unmutes. Hovering (or a long press on touch) shows a vertical
/// slider above the button; scrolling on either changes the volume.
class VolumeButton extends ConsumerStatefulWidget {
  const VolumeButton({super.key});

  @override
  ConsumerState<VolumeButton> createState() => _VolumeButtonState();
}

class _VolumeButtonState extends ConsumerState<VolumeButton> {
  final _popup = OverlayPortalController();
  final _link = LayerLink();
  Timer? _hideTimer;

  void _show() {
    _hideTimer?.cancel();
    _popup.show();
  }

  /// Waits a moment so the pointer can travel from the button to the popup.
  void _hideSoon() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 300), _popup.hide);
  }

  void _onScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
    // Scrolling while muted continues from the volume before the mute.
    final state = ref.read(playerServiceProvider);
    final volume = state.volumeBeforeMute ?? state.volume;
    final step = event.scrollDelta.dy < 0 ? _scrollStep : -_scrollStep;
    ref.read(playerServiceProvider.notifier).setVolume(volume + step);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  Widget _hoverable(Widget child) => MouseRegion(
    onEnter: (_) => _show(),
    onExit: (_) => _hideSoon(),
    child: Listener(onPointerSignal: _onScroll, child: child),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (volume, muted) = ref.watch(
      playerServiceProvider.select((s) => (s.volume, s.muted)),
    );
    final icon = muted || volume == 0
        ? Icons.volume_off_rounded
        : volume < 50
        ? Icons.volume_down_rounded
        : Icons.volume_up_rounded;

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _popup,
        overlayChildBuilder: (context) => Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.topCenter,
            followerAnchor: Alignment.bottomCenter,
            child: _hoverable(_VolumeSlider(volume: volume)),
          ),
        ),
        child: _hoverable(
          GestureDetector(
            onLongPress: _show,
            child: IconButton(
              icon: Icon(icon),
              iconSize: playerIconSize,
              tooltip: muted ? l10n.playerUnmute : l10n.playerMute,
              onPressed: ref.read(playerServiceProvider.notifier).toggleMute,
            ),
          ),
        ),
      ),
    );
  }
}

class _VolumeSlider extends ConsumerWidget {
  const _VolumeSlider({required this.volume});

  final double volume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 3,
      child: SizedBox(
        width: 48,
        height: 160,
        child: RotatedBox(
          quarterTurns: 3,
          child: Slider(
            value: volume.clamp(0, 100),
            max: 100,
            label: context.l10n.playerVolume,
            semanticFormatterCallback: (value) => '${value.round()}%',
            onChanged: ref.read(playerServiceProvider.notifier).setVolume,
          ),
        ),
      ),
    );
  }
}
