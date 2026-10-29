import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';

/// The heading of a block of a page: a title, an optional [count] after it
/// and a "see all" chevron button beside them. The title is the only part
/// that shrinks (one line, ellipsis), so the count and the chevron stay
/// visible in a narrow box.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.count,
    this.onSeeAll,
    this.padding = const EdgeInsets.fromLTRB(32, 16, 24, 0),
  });

  final String title;

  /// Shown as a plain number after the title; nothing when null.
  final int? count;

  /// Opens the full list; the button stays in place but is disabled when null.
  final VoidCallback? onSeeAll;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = this.count;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Flexible(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
          if (count != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: Text(
                '$count',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          IconButton(
            tooltip: context.l10n.homeSeeAll,
            icon: const Icon(AppIcons.chevronRight),
            onPressed: onSeeAll,
          ),
        ],
      ),
    );
  }
}
