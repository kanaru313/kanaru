import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

/// Rows a section shows before "Show all".
const searchSectionPreview = 8;

/// The slivers of one result group: a header with its [count], the [items]
/// (the first [searchSectionPreview] unless [expanded]), then a toggle
/// ("Show all" / "Show less") and, once [expanded], the [footer]. A [count]
/// above the [items] means the rows are only the best ones, and the toggle
/// says so. Rows are built lazily, so a long group stays cheap.
List<Widget> searchSectionSlivers<T>({
  required BuildContext context,
  required String title,
  required int count,
  required List<T> items,
  required bool expanded,
  required VoidCallback onToggle,
  required Widget Function(T item) rowBuilder,
  Widget? footer,
}) {
  final l10n = context.l10n;
  final collapsible = items.length > searchSectionPreview;
  final shown = expanded || !collapsible ? items.length : searchSectionPreview;
  final label = expanded
      ? l10n.searchShowLess
      : count > items.length
      ? l10n.searchShowTop(items.length)
      : l10n.searchShowAll(items.length);
  return [
    SliverToBoxAdapter(
      child: _SectionHeader(title: title, count: count),
    ),
    SliverList.builder(
      itemCount: shown,
      itemBuilder: (context, i) => rowBuilder(items[i]),
    ),
    if (collapsible)
      SliverToBoxAdapter(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextButton(
              onPressed: onToggle,
              child: Text(label),
            ),
          ),
        ),
      ),
    if (footer != null && expanded) SliverToBoxAdapter(child: footer),
  ];
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    ).format(count);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 4),
      child: Semantics(
        header: true,
        label: '$title, $number',
        excludeSemantics: true,
        child: Text.rich(
          TextSpan(
            text: title,
            children: [
              TextSpan(
                text: '  $number',
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
