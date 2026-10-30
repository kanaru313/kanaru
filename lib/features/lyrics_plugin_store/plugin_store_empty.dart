import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'add_repository_dialog.dart';
import 'plugin_store_actions.dart';

/// The store with no repository and no plugin: two ways to get started.
class PluginStoreEmpty extends StatelessWidget {
  const PluginStoreEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.extension_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.lyricsStoreEmptyTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add),
                  label: Text(l10n.lyricsStoreAddRepository),
                  onPressed: () => showAddRepositoryDialog(context),
                ),
                OutlinedButton(
                  onPressed: () =>
                      PluginStoreActions(context).installFromFile(),
                  child: Text(l10n.lyricsStoreMenuInstallFile),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
