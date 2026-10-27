import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';

/// Icon, name, full path, optional counts and the Play and Shuffle buttons
/// of a folder page, then [trailing] buttons.
class FolderHeader extends StatelessWidget {
  const FolderHeader({
    super.key,
    required this.name,
    required this.path,
    required this.onPlay,
    required this.onShuffle,
    this.counts,
    this.trailing = const [],
  });

  final String name;
  final String path;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;

  /// The counts line under the path, given the muted text style.
  final Widget Function(TextStyle? style)? counts;

  /// Buttons after Shuffle.
  final List<Widget> trailing;

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
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  path,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
                if (counts != null) ...[
                  const SizedBox(height: 4),
                  counts!(muted),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: onPlay,
                      icon: const Icon(AppIcons.play),
                      label: Text(l10n.albumsPlay),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: onShuffle,
                      icon: const Icon(AppIcons.shuffle),
                      label: Text(l10n.libraryShuffle),
                    ),
                    ...trailing,
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
