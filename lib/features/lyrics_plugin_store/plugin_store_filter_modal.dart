import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/lyrics_plugin_spec.dart' show PluginKind;
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/context_modal/context_modal_route.dart';
import 'plugin_store_filter_group.dart';
import 'plugin_store_providers.dart';

/// Opens the filter modal of the store page that started on [initialKind]:
/// a dialog in a wide window, a bottom sheet in a narrow one. Picks apply to
/// the list behind it at once; "Done" only closes.
Future<void> showPluginStoreFilterModal(
  BuildContext context,
  PluginKind? initialKind,
) => showContextModal<void>(
  context,
  semanticLabel: context.l10n.lyricsStoreFilterTitle,
  root: ContextModalPage(
    key: 'plugin-store-filters',
    headerBuilder: (context, nav) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                context.l10n.lyricsStoreFilterTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          IconButton(
            tooltip: context.l10n.contextModalClose,
            icon: const Icon(AppIcons.close),
            onPressed: () => nav.close(),
          ),
        ],
      ),
    ),
    bodyBuilder: (context, nav) => [_FilterGroups(initialKind: initialKind)],
    footerBuilder: (context, nav) =>
        _FilterFooter(initialKind: initialKind, onDone: () => nav.close()),
  ),
);

/// The visible groups, rebuilt as the picks change.
class _FilterGroups extends ConsumerWidget {
  const _FilterGroups({required this.initialKind});

  final PluginKind? initialKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(pluginStoreViewProvider(initialKind)).value;
    final filters = ref.read(pluginStoreFiltersProvider(initialKind).notifier);
    if (view == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in view.facets)
          if (group.visible)
            PluginStoreFilterGroup(
              key: ValueKey(group.facet),
              group: group,
              onToggle: (key) => filters.toggle(group.facet, key),
              onClear: () => filters.clear(group.facet),
            ),
      ],
    );
  }
}

/// "Showing N plugins", Clear all, Done.
class _FilterFooter extends ConsumerWidget {
  const _FilterFooter({required this.initialKind, required this.onDone});

  final PluginKind? initialKind;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final view = ref.watch(pluginStoreViewProvider(initialKind)).value;
    final active = view?.filters.activeCount ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.lyricsStoreFilterShowing(view?.shownCount ?? 0),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: active == 0
                ? null
                : ref
                      .read(pluginStoreFiltersProvider(initialKind).notifier)
                      .clearAll,
            child: Text(l10n.lyricsStoreFilterClearAll),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onDone,
            child: Text(l10n.lyricsStoreFilterDone),
          ),
        ],
      ),
    );
  }
}
