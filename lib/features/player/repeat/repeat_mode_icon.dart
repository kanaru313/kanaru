import 'package:material_ui/material_ui.dart' hide RepeatMode;

import '../../../core/player/repeat_mode.dart';
import '../../../shared/icons/app_icons.dart';

/// Icon of a repeat mode, in the surrounding icon colour. [counted] shows the
/// circled [times] instead of the base [mode]. [menu] picks the glyph for
/// "off": a playlist that stops at its end in the menu, the plain (unlit)
/// repeat arrows on the button.
class RepeatModeIcon extends StatelessWidget {
  const RepeatModeIcon({
    super.key,
    required this.mode,
    this.counted = false,
    this.times = 0,
    this.size,
    this.menu = false,
  });

  final RepeatMode mode;
  final bool counted;
  final int times;
  final double? size;
  final bool menu;

  @override
  Widget build(BuildContext context) {
    final size = this.size ?? IconTheme.of(context).size ?? 24;
    if (counted) return RepeatCountIcon(count: times, size: size);
    return switch (mode) {
      RepeatMode.off => Icon(
        menu ? AppIcons.repeatStopAtEnd : AppIcons.repeat,
        size: size,
      ),
      RepeatMode.one => Icon(AppIcons.repeatOne, size: size),
      RepeatMode.all => Icon(AppIcons.repeat, size: size),
      RepeatMode.allShuffled => SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(AppIcons.repeat, size: size),
            Positioned(
              right: -size * 0.12,
              bottom: -size * 0.12,
              child: Icon(AppIcons.shuffle, size: size * 0.5),
            ),
          ],
        ),
      ),
    };
  }
}

/// A number in a circle outline, sized like an icon. The number is also in
/// the label next to it, so screen readers skip this.
class RepeatCountIcon extends StatelessWidget {
  const RepeatCountIcon({super.key, required this.count, required this.size});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color =
        IconTheme.of(context).color ?? DefaultTextStyle.of(context).style.color;
    // Same footprint as a glyph: the icon's live area is 20/24 of its box.
    final circle = size * 20 / 24;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Container(
            width: circle,
            height: circle,
            alignment: Alignment.center,
            padding: EdgeInsets.all(circle * 0.14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color ?? const Color(0xFF000000),
                width: 1.6,
              ),
            ),
            child: FittedBox(
              child: Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
