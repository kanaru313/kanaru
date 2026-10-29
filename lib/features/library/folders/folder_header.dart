import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import 'folder_art.dart';
import 'folder_tree.dart';

/// Art, [breadcrumb], name, optional counts and the Play and Shuffle buttons
/// of a folder page, then [trailing] buttons. The name carries the full path
/// as a tooltip.
class FolderHeader extends StatelessWidget {
  const FolderHeader({
    super.key,
    required this.folder,
    this.breadcrumb,
    this.directArt = false,
    required this.onPlay,
    required this.onShuffle,
    this.counts,
    this.trailing = const [],
  });

  final FolderNode folder;

  /// Whether the art shows the cover of the folder's own songs.
  final bool directArt;

  /// The line above the name that says where the folder is.
  final Widget? breadcrumb;

  /// Null disables the button.
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;

  /// The counts line under the name, given the muted text style.
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
          FolderArt(folder: folder, size: 132, direct: directArt),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (breadcrumb != null) ...[
                  breadcrumb!,
                  const SizedBox(height: 4),
                ],
                Tooltip(
                  message: folder.path,
                  child: Text(
                    folder.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
