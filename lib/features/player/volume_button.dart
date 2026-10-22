import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/player_service.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'playback_controls.dart';

/// Volume step for one scroll notch.
const _scrollStep = 5.0;

/// Click mutes/unmutes. Hovering (or a long press on touch) shows a vertical
/// slider above the button, the volume in percent on top; scrolling on
/// either changes the volume.
class VolumeButton extends ConsumerStatefulWidget {
  const VolumeButton({super.key, this.onPopupChanged});

  /// Called with `true` when the slider popup opens and `false` when it
  /// closes (also when the button leaves the tree with the popup open). The
  /// popup lives in the overlay, outside the button's own pointer regions, so
  /// a parent that reacts to the pointer being on it needs this to know the
  /// pointer is still on the volume control.
  final ValueChanged<bool>? onPopupChanged;

  @override
  ConsumerState<VolumeButton> createState() => _VolumeButtonState();
}

class _VolumeButtonState extends ConsumerState<VolumeButton> {
  final _popup = OverlayPortalController();
  final _link = LayerLink();
  Timer? _hideTimer;

  /// Own flag: the portal controller is already detached in [dispose].
  bool _open = false;

  void _show() {
    _hideTimer?.cancel();
    if (_open) return;
    _open = true;
    _popup.show();
    widget.onPopupChanged?.call(true);
  }

  void _hide() {
    if (!_open) return;
    _open = false;
    _popup.hide();
    widget.onPopupChanged?.call(false);
  }

  /// Waits a moment so the pointer can travel from the button to the popup.
  void _hideSoon() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 300), _hide);
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
    if (_open) widget.onPopupChanged?.call(false);
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
        ? AppIcons.volumeOffRounded
        : volume < 50
        ? AppIcons.volumeDown
        : AppIcons.volumeUp;

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
    final theme = Theme.of(context);
    return Card(
      elevation: 3,
      child: SizedBox(
        width: 48,
        height: 184,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${volume.round()}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
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
          ],
        ),
      ),
    );
  }
}
