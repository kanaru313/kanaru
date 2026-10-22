import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import 'folder_counts_line.dart';
import 'folder_menu.dart';
import 'folder_tree.dart';

/// Icon, name, full path, counts and the Play, Shuffle and more buttons of a
/// folder page.
class FolderHeader extends StatelessWidget {
  const FolderHeader({super.key, required this.folder, required this.onAction});

  final FolderNode folder;
  final ValueChanged<FolderAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
      child: Row(
        children: [
          Icon(
            AppIcons.folderOutlined,
            size: 96,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folder.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  folder.path,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
                const SizedBox(height: 4),
                FolderCountsLine(folder: folder, style: muted),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => onAction(FolderAction.play),
                      icon: const Icon(AppIcons.play),
                      label: Text(l10n.albumsPlay),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => onAction(FolderAction.shuffle),
                      icon: const Icon(AppIcons.shuffle),
                      label: Text(l10n.libraryShuffle),
                    ),
                    FolderActionsButton(onSelected: onAction),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
