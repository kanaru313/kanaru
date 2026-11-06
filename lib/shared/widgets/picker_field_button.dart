import 'package:material_ui/material_ui.dart';

import '../icons/app_icons.dart';
import 'marquee_text.dart';

/// Pause before an overflowing [PickerFieldButton] label starts scrolling.
const Duration _fieldMarqueeDelay = Duration(milliseconds: 1200);

/// Minimum height of the compact stadium picker button.
const double _fieldMinHeight = 40;

/// A compact stadium button showing a one-line [MarqueeText] [label] and a
/// trailing expand chevron (`▾`), used to open a child selection modal.
///
/// When [onPressed] is `null`, the button is non-interactive and dimmed.
class PickerFieldButton extends StatelessWidget {
  const PickerFieldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.tooltip,
    this.focusNode,
  });

  /// Current choice shown in the button; scrolls when it overflows.
  final String label;

  /// Opens the picker; `null` dims the button and disables it.
  final VoidCallback? onPressed;

  /// Optional widget before the label.
  final Widget? leading;

  /// Optional tooltip of the button.
  final String? tooltip;

  /// Focus node of the button, for callers that move focus to it.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = onPressed != null;
    final leading = this.leading;
    final tooltip = this.tooltip;

    Widget button = Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            focusNode: focusNode,
            customBorder: const StadiumBorder(),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _fieldMinHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (leading != null) ...[
                      IconTheme.merge(
                        data: IconThemeData(
                          size: 20,
                          color: colors.onSurfaceVariant,
                        ),
                        child: leading,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: MarqueeText(
                        text: label,
                        startDelay: _fieldMarqueeDelay,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      AppIcons.expandMore,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (tooltip != null && tooltip.isNotEmpty) {
      button = Tooltip(message: tooltip, child: button);
    }
    return button;
  }
}
