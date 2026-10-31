import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'plugin_store_actions.dart';
import 'plugin_store_providers.dart';
import 'store_row_icon.dart';

/// Which section a store row belongs to; decides its action button.
enum StoreRowKind {
  /// Has a newer catalog version: the button updates.
  update,

  /// Installed, nothing newer: the button uninstalls.
  installed,

  /// In a catalog, not installed: the button installs.
  available,
}

/// One plugin in the store list: icon, name, where it comes from, and one
/// icon button (update, uninstall or install) that becomes a spinner while
/// that work runs. Tapping the row opens the plugin.
class PluginStoreRow extends ConsumerWidget {
  const PluginStoreRow({
    super.key,
    required this.row,
    required this.kind,
    required this.repo,
    required this.onOpen,
  });

  final StoreRow row;
  final StoreRowKind kind;

  /// The plugin's repository, for the catalog icon; null for a file plugin.
  final PluginRepo? repo;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final record = row.record;
    final slug = row.entry?.slug ?? record?.repoSlug;
    final busy = switch (kind) {
      StoreRowKind.update || StoreRowKind.installed =>
        record != null &&
            (ref
                    .watch(pluginStoreUpdatingProvider)
                    .value
                    ?.contains(record.installId) ??
                false),
      StoreRowKind.available =>
        row.repoUrl != null &&
            slug != null &&
            ref
                .watch(pluginStorePendingInstallsProvider)
                .contains(pendingInstallKey(row.repoUrl!, slug)),
    };
    final entry = row.entry;
    // An update row adds what the update changes after the repository name.
    final repoName = row.repoName ?? '';
    final subtitle =
        kind == StoreRowKind.update && record != null && entry != null
        ? [
            if (repoName.isNotEmpty) repoName,
            l10n.lyricsStoreUpdateVersions(record.version, entry.version),
          ].join(' · ')
        : row.isFromFile
        ? l10n.lyricsStoreFromFile
        : (row.repoName ?? '');
    return ListTile(
      onTap: onOpen,
      leading: StoreRowIcon(row: row, repo: repo),
      title: Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: busy
          ? Semantics(
              label: l10n.lyricsStoreWorking,
              child: const SizedBox.square(
                dimension: 48,
                child: Center(
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            )
          : _action(context, l10n),
    );
  }

  Widget? _action(BuildContext context, AppLocalizations l10n) {
    final colors = Theme.of(context).colorScheme;
    final record = row.record;
    switch (kind) {
      case StoreRowKind.update:
        if (record == null) return null;
        return _button(
          label: l10n.lyricsStoreUpdateTooltip,
          icon: AppIcons.updateAvailable,
          color: colors.primary,
          onPressed: () => PluginStoreActions(context).update(
            installId: record.installId,
            name: row.name,
            repoName: row.repoName,
            entry: row.entry,
            repoUrl: row.repoUrl,
            slug: row.entry?.slug,
          ),
        );
      case StoreRowKind.installed:
        if (record == null) return null;
        return _button(
          label: l10n.lyricsStoreUninstallTooltip,
          icon: AppIcons.deleteOutline,
          onPressed: () => PluginStoreActions(context).uninstall(record),
        );
      case StoreRowKind.available:
        final repoUrl = row.repoUrl;
        final entry = row.entry;
        if (repoUrl == null || entry == null) return null;
        return _button(
          label: l10n.lyricsStoreInstallTooltip,
          icon: AppIcons.download,
          color: colors.primary,
          onPressed: () => PluginStoreActions(context).install(
            repoUrl: repoUrl,
            slug: entry.slug,
            name: row.name,
            repoName: row.repoName,
            entry: entry,
          ),
        );
    }
  }

  Widget _button({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) => IconButton(
    tooltip: label,
    // The tooltip names the button for the mouse; the label for screen readers.
    icon: Icon(icon, semanticLabel: label, color: color),
    onPressed: onPressed,
  );
}
