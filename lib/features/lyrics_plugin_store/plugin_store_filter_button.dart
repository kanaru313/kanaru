import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/lyrics_plugin_spec.dart' show PluginKind;
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'plugin_store_filter_modal.dart';
import 'plugin_store_providers.dart';

/// The filter icon of the store's app bar: a badge with the number of groups
/// that have a pick, primary-coloured while any does. Absent while there is
/// nothing to filter by.
class PluginStoreFilterButton extends ConsumerWidget {
  const PluginStoreFilterButton({super.key, required this.initialKind});

  final PluginKind? initialKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(pluginStoreViewProvider(initialKind)).value;
    if (view == null || !view.hasFilters) return const SizedBox.shrink();
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final count = view.filters.activeCount;
    final active = count > 0;
    return Badge(
      isLabelVisible: active,
      backgroundColor: colors.primary,
      textColor: colors.onPrimary,
      label: ExcludeSemantics(child: Text('$count')),
      child: IconButton(
        tooltip: active
            ? l10n.lyricsStoreFilterActiveLabel(count)
            : l10n.lyricsStoreFilterTooltip,
        icon: Icon(AppIcons.filter, color: active ? colors.primary : null),
        onPressed: () => showPluginStoreFilterModal(context, initialKind),
      ),
    );
  }
}
