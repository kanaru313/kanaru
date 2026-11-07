import 'package:material_ui/material_ui.dart';

import '../playback_controls.dart';

/// Height of a header pill, as tall as the hover circle of the round icon
/// button beside it: the icon plus the icon button's 8 px padding each side.
const _pillHeight = playerIconSize + 16;

/// Air each side of a pill: what a round button's 48 px slot leaves around
/// its circle, so a pill sits as far from its neighbours as a round button.
const nowPlayingHeaderPillMargin = (48 - _pillHeight) / 2;

/// A Now Playing header button with a label: [leading] (or [icon]) followed by
/// [label] on a raised stadium, or a 20 px progress ring in place of the icon
/// while [busy]. Both lyrics buttons (translation and source) use it, so they
/// look alike. The label is one line and shrinks with an ellipsis to
/// [maxLabelWidth]; [tooltip] says what the button does. Pressing it runs
/// [onPressed]; `null` greys it out. A [muted] pill keeps the icon in the
/// label's colour instead of the primary one.
class NowPlayingHeaderPill extends StatelessWidget {
  const NowPlayingHeaderPill({
    super.key,
    this.icon,
    this.leading,
    required this.label,
    required this.tooltip,
    required this.maxLabelWidth,
    required this.onPressed,
    this.muted = false,
    this.busy = false,
    this.tabularFigures = false,
  }) : assert(
         (icon == null) != (leading == null),
         'Give exactly one of icon and leading',
       );

  final IconData? icon;
  final Widget? leading;
  final String label;
  final String tooltip;

  /// Most room the label may take.
  final double maxLabelWidth;

  final VoidCallback? onPressed;
  final bool muted;

  /// Whether a background task is running; replaces [leading]/[icon] with a
  /// 20 px progress indicator.
  final bool busy;

  /// Digits of one width, for a label that counts (a timer), so the pill
  /// does not change width every second.
  final bool tabularFigures;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: nowPlayingHeaderPillMargin,
      ),
      child: Tooltip(
        message: tooltip,
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: scheme.surfaceContainerHighest,
            foregroundColor: scheme.onSurfaceVariant,
            fixedSize: const Size.fromHeight(_pillHeight),
            visualDensity: VisualDensity.standard,
            padding: const EdgeInsetsDirectional.only(start: 10, end: 14),
            shape: const StadiumBorder(),
            textStyle: theme.textTheme.labelMedium,
          ),
          onPressed: onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (leading != null)
                // Dimmed like the label of a disabled Material button.
                Opacity(opacity: onPressed == null ? 0.38 : 1, child: leading)
              else
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
                  style: tabularFigures
                      ? const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
