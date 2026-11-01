import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/lyrics_plugin_spec.dart' show PluginKind;
import '../../l10n/l10n.dart';
import 'plugin_store_providers.dart';

/// The chips that pick what the store lists: Lyrics or Translate plugins.
class PluginStoreKindChips extends ConsumerWidget {
  const PluginStoreKindChips({super.key, required this.initialKind});

  /// The kind shown until a chip is picked.
  final PluginKind initialKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final kind = ref.watch(pluginStoreKindProvider(initialKind)) ?? initialKind;
    final notifier = ref.read(pluginStoreKindProvider(initialKind).notifier);
    Widget chip(String label, PluginKind value) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: kind == value,
        onSelected: (_) => notifier.set(value),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          chip(l10n.lyricsStoreKindLyrics, PluginKind.lyrics),
          chip(l10n.lyricsStoreKindTranslate, PluginKind.translate),
        ],
      ),
    );
  }
}
