import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import 'now_playing_open_provider.dart';

/// Makes [child], the cover on the player bar, open Now Playing. Hovering
/// darkens and enlarges the cover and fades in an expand icon over it.
class NowPlayingOpenCover extends ConsumerStatefulWidget {
  const NowPlayingOpenCover({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NowPlayingOpenCover> createState() =>
      _NowPlayingOpenCoverState();
}

class _NowPlayingOpenCoverState extends ConsumerState<NowPlayingOpenCover> {
  static const _duration = Duration(milliseconds: 300);

  bool _hovered = false;

  void _setHovered(bool hovered) => setState(() => _hovered = hovered);

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.nowPlayingOpen;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: GestureDetector(
            onTap: ref.read(nowPlayingOpenProvider.notifier).open,
            child: ClipRect(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedScale(
                    scale: _hovered ? 1.2 : 1,
                    duration: _duration,
                    child: widget.child,
                  ),
                  // Brightness .6 on hover.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _hovered ? 0.4 : 0,
                        duration: _duration,
                        child: const ColoredBox(color: Colors.black),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _hovered ? 1 : 0,
                      duration: _duration,
                      child: AnimatedScale(
                        scale: _hovered ? 1 : 0.6,
                        duration: _duration,
                        child: const Icon(
                          AppIcons.openFull,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
