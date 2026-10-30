import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'plugin_store_actions.dart';

enum _Choice { installFile, repositories, refreshAll }

/// The ⋮ menu of the store page: install from a file, open the repository
/// list, refresh everything.
class PluginStoreMenu extends StatelessWidget {
  const PluginStoreMenu({
    super.key,
    required this.repositoryCount,
    required this.onOpenRepositories,
  });

  final int repositoryCount;
  final VoidCallback onOpenRepositories;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<_Choice>(
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      icon: const Icon(AppIcons.more),
      onSelected: (choice) => switch (choice) {
        _Choice.installFile => PluginStoreActions(context).installFromFile(),
        _Choice.repositories => onOpenRepositories(),
        _Choice.refreshAll => PluginStoreActions(context).refreshAll(),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _Choice.installFile,
          child: ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: Text(l10n.lyricsStoreMenuInstallFile),
          ),
        ),
        PopupMenuItem(
          value: _Choice.repositories,
          child: ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(l10n.lyricsStoreMenuRepositories(repositoryCount)),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _Choice.refreshAll,
          child: ListTile(
            leading: const Icon(AppIcons.refresh),
            title: Text(l10n.lyricsStoreMenuRefreshAll),
          ),
        ),
      ],
    );
  }
}
