import 'package:material_ui/material_ui.dart';

/// Six grey bars where the lyrics will be. They pulse while the lyrics load,
/// and stay still when the system asks for reduced motion.
class LyricsSkeleton extends StatefulWidget {
  const LyricsSkeleton({super.key});

  @override
  State<LyricsSkeleton> createState() => _LyricsSkeletonState();
}

class _LyricsSkeletonState extends State<LyricsSkeleton>
    with SingleTickerProviderStateMixin {
  static const _widths = [0.9, 0.7, 0.85, 0.6, 0.75, 0.5];

  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse
        ..stop()
        ..value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 1).animate(_pulse),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
          child: Column(
            key: const ValueKey('song-lyrics-skeleton'),
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 9,
            children: [
              for (final width in _widths)
                FractionallySizedBox(
                  widthFactor: width,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const SizedBox(height: 11),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
