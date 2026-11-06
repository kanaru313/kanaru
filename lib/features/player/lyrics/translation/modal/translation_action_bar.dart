import 'package:material_ui/material_ui.dart';

import '../../../../../shared/widgets/marquee_text.dart';

/// Pause before an overflowing action bar label starts scrolling.
const Duration _actionBarMarqueeDelay = Duration(milliseconds: 300);

/// Fixed bottom action bar outside the scroll area of the translation modal.
///
/// Shows a [text] line in a [MarqueeText] beside a [FilledButton] labeled
/// [actionLabel].
class TranslationActionBar extends StatelessWidget {
  const TranslationActionBar({
    super.key,
    required this.text,
    required this.actionLabel,
    required this.onPressed,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MarqueeText(
                    text: text,
                    startDelay: _actionBarMarqueeDelay,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: FilledButton(
                onPressed: onPressed,
                child: Text(
                  actionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
