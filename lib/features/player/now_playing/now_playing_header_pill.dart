import 'package:material_ui/material_ui.dart';

import '../playback_controls.dart';

/// Height of a header pill, as tall as the round icon button beside it.
const _pillHeight = 40.0;

/// A Now Playing header button with a label: [icon] followed by [label] on a
/// raised stadium. Both lyrics buttons (translation and source) use it, so
/// they look alike. The label is one line and shrinks with an ellipsis to
/// [maxLabelWidth]; [tooltip] says what the button does. Pressing it runs
/// [onPressed]; `null` greys it out. A [muted] pill keeps the icon in the
/// label's colour instead of the primary one.
class NowPlayingHeaderPill extends StatelessWidget {
  const NowPlayingHeaderPill({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.maxLabelWidth,
    required this.onPressed,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String tooltip;

  /// Most room the label may take.
  final double maxLabelWidth;

  final VoidCallback? onPressed;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tooltip(
      message: tooltip,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size(0, _pillHeight),
          maximumSize: const Size.fromHeight(_pillHeight),
          padding: const EdgeInsetsDirectional.only(start: 10, end: 14),
          shape: const StadiumBorder(),
          textStyle: theme.textTheme.labelMedium,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: playerIconSize,
              // Null lets the button's own (or disabled) colour through.
              color: onPressed == null || muted ? null : scheme.primary,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxLabelWidth),
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
