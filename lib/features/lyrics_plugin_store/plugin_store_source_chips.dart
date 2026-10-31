import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import '../../l10n/l10n.dart';
import 'plugin_store_providers.dart';

/// The chips that narrow the list to one source: Tất cả, each repository,
/// Từ file. They scroll sideways. Hidden unless [PluginStoreView.showSourceChips].
class PluginStoreSourceChips extends ConsumerWidget {
  const PluginStoreSourceChips({super.key, required this.view});

  final PluginStoreView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!view.showSourceChips) return const SizedBox.shrink();
    final l10n = context.l10n;
    final filter = ref.watch(pluginStoreFilterProvider);
    final notifier = ref.read(pluginStoreFilterProvider.notifier);
    Widget chip(String label, StoreSourceFilter value) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: filter == value,
        onSelected: (_) => notifier.set(value),
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          chip(l10n.lyricsStoreChipAll, const StoreSourceFilter.all()),
          for (final repo in view.sources)
            chip(repo.name, StoreSourceFilter.repo(repo.url)),
          if (view.hasFileSource)
            chip(l10n.lyricsStoreFromFile, const StoreSourceFilter.fromFile()),
        ],
      ),
    );
  }
}
