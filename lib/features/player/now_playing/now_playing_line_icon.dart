import 'package:material_ui/material_ui.dart';

/// [line] with [icon] in front, both in the centered row of the artist and
/// album lines. The icon is not part of the line, so it is neither dimmed
/// nor tappable.
class NowPlayingLineWithIcon extends StatelessWidget {
  const NowPlayingLineWithIcon({
    super.key,
    required this.icon,
    required this.line,
  });

  final IconData icon;
  final Widget line;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      ExcludeSemantics(
        child: Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(width: 8),
      Flexible(child: line),
    ],
  );
}
