import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/search/search_prefs_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';

const _rowHeight = 40.0;

/// Rows shown before the list scrolls.
const _visibleRows = 8;

/// Narrowest the panel gets, even under a narrow search field.
const topBarSearchHistoryMinWidth = 280.0;

/// Recent searches under the top bar field: a row per query with a remove
/// button, and "Clear all" at the end. The rows read the history themselves,
/// so removing one updates the panel in place. Nothing in it takes keyboard
/// focus and it sits in the field's tap region, so the field keeps focus.
class TopBarSearchHistoryMenu extends ConsumerWidget {
  const TopBarSearchHistoryMenu({
    super.key,
    required this.selected,
    required this.onPick,
  });

  /// Index of the row picked with the arrow keys, or -1.
  final int selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final history = ref.watch(searchPrefsProvider).value?.history ?? const [];
    final prefs = ref.read(searchPrefsProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    return TextFieldTapRegion(
      child: ExcludeFocus(
        child: Semantics(
          label: l10n.searchHistoryTitle,
          container: true,
          child: Material(
            elevation: 3,
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                  // The container's label already announces the title.
                  child: ExcludeSemantics(
                    child: Text(
                      l10n.searchHistoryTitle,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: _rowHeight * _visibleRows,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemExtent: _rowHeight,
                    itemCount: history.length,
                    itemBuilder: (context, i) => _HistoryRow(
                      entry: history[i],
                      highlighted: i == selected,
                      onPick: () => onPick(history[i]),
                      onRemove: () => prefs.remove(history[i]),
                    ),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextButton(
                      onPressed: prefs.clear,
                      child: Text(l10n.searchHistoryClearAll),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.highlighted,
    required this.onPick,
    required this.onRemove,
  });

  final String entry;
  final bool highlighted;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: highlighted,
      child: Material(
        color: highlighted ? colors.secondaryContainer : Colors.transparent,
        child: InkWell(
          onTap: onPick,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
            child: Row(
              spacing: 12,
              children: [
                Icon(
                  AppIcons.history,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                Expanded(
                  child: Text(
                    entry,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(AppIcons.close, size: 16),
                  tooltip: context.l10n.searchHistoryRemove,
                  visualDensity: VisualDensity.compact,
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
