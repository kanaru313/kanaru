import 'package:material_ui/material_ui.dart';

import '../icons/app_icons.dart';
import 'marquee_text.dart';

/// Pause before an overflowing [SelectionRow] title starts scrolling. The
/// marquee cycle holds the text at rest for another 0.9 s, so the text starts
/// moving about 1.2 s after the row appears.
const Duration _titleMarqueeDelay = Duration(milliseconds: 300);

/// Width reserved for the trailing check mark so selected and unselected rows
/// give their title the same width.
const double _checkSlotSize = 24;

/// One option row in a selection list: a rounded tonal fill and a trailing
/// check mark when [selected], or a transparent row with an empty slot of the
/// same width when not selected.
class SelectionRow extends StatelessWidget {
  const SelectionRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.focusNode,
    this.autofocus = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;

  /// Called when the row is tapped or activated with Enter or Space; `null`
  /// leaves the row disabled.
  final VoidCallback? onTap;

  /// Focus node of the row, for callers that move focus to it.
  final FocusNode? focusNode;

  /// Whether the row takes focus when first built.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fg = selected ? colors.onSecondaryContainer : colors.onSurface;
    final subColor = selected
        ? colors.onSecondaryContainer.withValues(alpha: 0.8)
        : colors.onSurfaceVariant;
    final subtitle = this.subtitle;
    final leading = this.leading;

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Material(
          color: selected ? colors.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            focusNode: focusNode,
            autofocus: autofocus,
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    if (leading != null) ...[
                      leading,
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MarqueeText(
                            text: title,
                            startDelay: _titleMarqueeDelay,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: fg,
                            ),
                          ),
                          if (subtitle != null && subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: subColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: _checkSlotSize,
                      height: _checkSlotSize,
                      child: selected
                          ? Icon(
                              AppIcons.check,
                              size: _checkSlotSize,
                              color: colors.onSecondaryContainer,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
