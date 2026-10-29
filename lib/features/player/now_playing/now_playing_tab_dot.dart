import 'package:material_ui/material_ui.dart';

/// Length of a page change in the narrow layout and of its dots' own
/// animation.
const nowPlayingTabDuration = Duration(milliseconds: 300);

/// One tab: a 6 px dot, or a 16 × 6 bar when selected. Hovering enlarges it
/// a little and shows the tab name.
class NowPlayingTabDot extends StatefulWidget {
  const NowPlayingTabDot({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<NowPlayingTabDot> createState() => _NowPlayingTabDotState();
}

class _NowPlayingTabDotState extends State<NowPlayingTabDot> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : nowPlayingTabDuration;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            // A roomy hit area around the tiny indicator.
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: AnimatedScale(
                scale: _hovered ? 1.3 : 1,
                duration: duration,
                curve: Curves.easeOutQuart,
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutQuart,
                  width: widget.selected ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? colors.primary
                        : colors.onSurfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(
                      widget.selected ? 4 : 3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
