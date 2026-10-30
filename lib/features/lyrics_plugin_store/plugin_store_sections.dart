import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import '../../l10n/l10n.dart';
import 'plugin_store_actions.dart';
import 'plugin_store_row.dart';

/// The store list: the sections Cập nhật, Đã cài and Chưa cài (empty ones are
/// left out), and the note about plugins that need a newer Kanaru.
class PluginStoreSections extends StatelessWidget {
  const PluginStoreSections({
    super.key,
    required this.view,
    required this.onOpenInstalled,
    required this.onOpenCatalogItem,
  });

  final PluginStoreView view;
  final void Function(String installId) onOpenInstalled;
  final void Function(String repoUrl, String slug) onOpenCatalogItem;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final repos = {for (final r in view.sources) r.url: r};
    Widget section(
      String title,
      List<StoreRow> rows,
      StoreRowKind kind, {
      Widget? action,
    }) => _Section(
      title: title,
      action: action,
      children: [
        for (final row in rows)
          PluginStoreRow(
            key: ValueKey(
              '${kind.name}:${row.record?.installId ?? '${row.repoUrl}/${row.entry?.slug}'}',
            ),
            row: row,
            kind: kind,
            repo: repos[row.repoUrl],
            onOpen: () {
              final record = row.record;
              final slug = row.entry?.slug;
              if (record != null) {
                onOpenInstalled(record.installId);
              } else if (row.repoUrl != null && slug != null) {
                onOpenCatalogItem(row.repoUrl!, slug);
              }
            },
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (view.updates.isNotEmpty)
          section(
            l10n.lyricsStoreSectionUpdates(view.updates.length),
            view.updates,
            StoreRowKind.update,
            action: TextButton(
              onPressed: () => PluginStoreActions(context).updateAll(),
              child: Text(l10n.lyricsStoreUpdateAll),
            ),
          ),
        if (view.installed.isNotEmpty)
          section(
            l10n.lyricsStoreSectionInstalled(view.installed.length),
            view.installed,
            StoreRowKind.installed,
          ),
        if (view.notInstalled.isNotEmpty)
          section(
            l10n.lyricsStoreSectionAvailable(view.notInstalled.length),
            view.notInstalled,
            StoreRowKind.available,
          ),
        if (view.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.lyricsStoreNoMatch,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (view.needsNewerApp > 0)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.lyricsStoreNeedsNewerFooter(view.needsNewerApp),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.action});

  final String title;
  final Widget? action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                ?action,
              ],
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}
