import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import 'folder_tree.dart';

/// "♪ 12 · folder 3": the songs and the folders below a folder, as small
/// icons and numbers. Folders are left out when there are none. Read out as
/// a sentence. With [directSongs] only that many songs are shown (a folder's
/// own songs, in the flat view), without the folders.
class FolderCountsLine extends StatelessWidget {
  const FolderCountsLine({
    super.key,
    required this.folder,
    this.style,
    this.directSongs,
  });

  final FolderNode folder;
  final TextStyle? style;
  final int? directSongs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle =
        style ??
        theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
    final iconSize = (textStyle?.fontSize ?? 12) + 2;
    Widget count(IconData icon, int value) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: textStyle?.color),
        const SizedBox(width: 2),
        Text('$value', style: textStyle),
      ],
    );
    final direct = directSongs;
    if (direct != null) {
      return Semantics(
        label: context.l10n.albumsSongCount(direct),
        excludeSemantics: true,
        child: count(AppIcons.musicNoteOutlined, direct),
      );
    }
    return Semantics(
      label: context.l10n.foldersCounts(folder.songs, folder.subfolders),
      excludeSemantics: true,
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          count(AppIcons.musicNoteOutlined, folder.songs),
          if (folder.subfolders > 0)
            count(AppIcons.folderOutlined, folder.subfolders),
        ],
      ),
    );
  }
}
