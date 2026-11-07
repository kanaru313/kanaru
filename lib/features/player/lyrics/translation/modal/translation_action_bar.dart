import 'package:material_ui/material_ui.dart';

/// Fixed bottom action bar outside the scroll area of the translation modal.
///
/// Holds one right-aligned [FilledButton] labeled [actionLabel]; the button
/// may use the whole bar width, and the label ellipsizes past it.
class TranslationActionBar extends StatelessWidget {
  const TranslationActionBar({
    super.key,
    required this.actionLabel,
    required this.onPressed,
  });

  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 16, 14),
        child: Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: onPressed,
            child: Text(
              actionLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
