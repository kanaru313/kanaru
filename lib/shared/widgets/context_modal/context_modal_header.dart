import 'package:material_ui/material_ui.dart';

/// One-line, ellipsized text for a [ContextModalHeader] line.
Widget contextModalHeaderLine(String text, TextStyle? style) =>
    Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);

/// A small rounded note under a header's text lines (the play time of a
/// history row, a rank): one ellipsized line on a `secondaryContainer` pill.
class ContextModalHeaderChip extends StatelessWidget {
  const ContextModalHeaderChip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSecondaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Top of an item modal: [leading] (cover or avatar), the text [lines], an
/// optional [trailing] widget and an optional [below] block.
///
/// With [onTap] the whole header, padding included, is one target: the ink
/// fills the full width and has no radius (the dialog or sheet frame clips
/// the corners). A [trailing] button keeps its own tap, which wins the
/// gesture arena, so [onTap] does not fire for it. [canRequestFocus] is false
/// by default so the first action row takes keyboard focus.
class ContextModalHeader extends StatelessWidget {
  const ContextModalHeader({
    super.key,
    required this.leading,
    required this.lines,
    this.trailing,
    this.below,
    this.onTap,
    this.tapHint,
    this.canRequestFocus = false,
  });

  final Widget leading;
  final List<Widget> lines;
  final Widget? trailing;

  /// Block under the row (the playlist description), inside the target.
  final Widget? below;
  final VoidCallback? onTap;

  /// Screen reader hint of the header button; only used with [onTap].
  final String? tapHint;
  final bool canRequestFocus;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    final below = this.below;
    final padded = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              leading,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: lines,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                SizedBox(width: 48, child: Center(child: trailing)),
              ],
            ],
          ),
          if (below != null)
            Padding(
              padding: const EdgeInsets.only(top: 10, right: 10),
              child: below,
            ),
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) return padded;
    return Semantics(
      container: true,
      button: true,
      hint: tapHint,
      child: InkWell(
        onTap: tap,
        canRequestFocus: canRequestFocus,
        child: padded,
      ),
    );
  }
}
