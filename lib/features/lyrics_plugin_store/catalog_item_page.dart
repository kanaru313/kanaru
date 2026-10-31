import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugin_record.dart';
import '../../core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'plugin_store_actions.dart';
import 'plugin_store_providers.dart';
import 'store_row_icon.dart';

/// The page of one plugin a repository offers: who wrote it, its version,
/// description, repository, the hosts it may reach, and "Cài".
///
/// A plugin that is installed (already, or from this page) shows an "Đã cài"
/// mark and a button that calls [onOpenInstalled]. The page never leaves by
/// itself, so going back from the installed page does not bounce forward again.
class CatalogItemPage extends ConsumerStatefulWidget {
  const CatalogItemPage({
    super.key,
    required this.repoUrl,
    required this.slug,
    required this.onOpenInstalled,
  });

  final String repoUrl;
  final String slug;
  final void Function(String installId) onOpenInstalled;

  @override
  ConsumerState<CatalogItemPage> createState() => _CatalogItemPageState();
}

class _CatalogItemPageState extends ConsumerState<CatalogItemPage> {
  LyricsPluginRecord? _installed(PluginStoreInput input) {
    for (final r in input.records) {
      if (!r.isRemoved &&
          r.repoUrl == widget.repoUrl &&
          r.repoSlug == widget.slug) {
        return r;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final input = ref.watch(pluginStoreRawInputProvider).value;
    if (input == null) {
      return PageScaffold(
        title: l10n.lyricsStoreTitle,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final installed = _installed(input);
    PluginRepo? repo;
    for (final r in input.repos) {
      if (r.url == widget.repoUrl) repo = r;
    }
    final entry = repo?.entry(widget.slug);
    if (repo == null || entry == null) {
      return PageScaffold(
        title: l10n.lyricsStoreTitle,
        body: Center(child: Text(l10n.lyricsStoreItemNotFound)),
      );
    }
    final row = StoreRow(
      name: entry.name,
      author: entry.author,
      hosts: entry.hosts,
      entry: entry,
      repoUrl: repo.url,
      repoName: repo.name,
    );
    final theme = Theme.of(context);
    final author = entry.author.isEmpty
        ? l10n.lyricsStoreItemUnknownAuthor
        : l10n.lyricsStoreItemAuthor(entry.author);
    final pending = ref
        .watch(pluginStorePendingInstallsProvider)
        .contains(pendingInstallKey(repo.url, entry.slug));
    final repoName = repo.name;
    final repoUrl = repo.url;
    return PageScaffold(
      title: l10n.pluginDetailsTitle,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              ListTile(
                leading: StoreRowIcon(row: row, repo: repo, size: 48),
                title: Text(entry.name, style: theme.textTheme.titleLarge),
                subtitle: Text('$author · v${entry.version}'),
                trailing: installed != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(label: Text(l10n.lyricsStoreItemInstalled)),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () =>
                                widget.onOpenInstalled(installed.installId),
                            child: Text(l10n.lyricsStoreItemOpenInstalled),
                          ),
                        ],
                      )
                    : FilledButton.icon(
                        icon: pending
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.file_download_outlined),
                        label: Text(l10n.lyricsStoreItemInstall),
                        onPressed: pending
                            ? null
                            : () => PluginStoreActions(context).install(
                                repoUrl: repoUrl,
                                slug: entry.slug,
                                name: entry.name,
                                repoName: repoName,
                                entry: entry,
                              ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  l10n.lyricsStoreItemInfo,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              if (entry.description.isNotEmpty)
                _Field(
                  label: l10n.lyricsStoreItemDescription,
                  lines: [entry.description],
                ),
              _Field(
                label: l10n.lyricsStoreItemRepo,
                lines: [repoName, repoUrl],
              ),
              _Field(label: l10n.lyricsStoreItemHosts, lines: entry.hosts),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.lines});

  final String label;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final line in lines) Text(line),
        ],
      ),
    );
  }
}
