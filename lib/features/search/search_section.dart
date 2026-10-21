import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

/// Rows a section shows before "Show all".
const searchSectionPreview = 8;

/// The slivers of one result group: a header with its [count], the [items]
/// (the first [searchSectionPreview] unless [expanded]), then "Show all" or
/// the [footer]. Rows are built lazily, so a long group stays cheap.
List<Widget> searchSectionSlivers<T>({
  required BuildContext context,
  required String title,
  required int count,
  required List<T> items,
  required bool expanded,
  required VoidCallback onShowAll,
  required Widget Function(T item) rowBuilder,
  Widget? footer,
}) {
  final shown = expanded || items.length <= searchSectionPreview
      ? items.length
      : searchSectionPreview;
  final canExpand = !expanded && items.length > searchSectionPreview;
  return [
    SliverToBoxAdapter(
      child: _SectionHeader(title: title, count: count),
    ),
    SliverList.builder(
      itemCount: shown,
      itemBuilder: (context, i) => rowBuilder(items[i]),
    ),
    if (canExpand)
      SliverToBoxAdapter(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextButton(
              onPressed: onShowAll,
              child: Text(context.l10n.searchShowAll(items.length)),
            ),
          ),
        ),
      ),
    if (footer != null && !canExpand) SliverToBoxAdapter(child: footer),
  ];
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 4),
      child: Semantics(
        header: true,
        child: Text.rich(
          TextSpan(
            text: title,
            children: [
              TextSpan(
                text: '  $count',
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
