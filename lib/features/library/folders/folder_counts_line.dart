import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import 'folder_tree.dart';
import 'hidden_entries.dart';

/// "♪ 12 · folder 3": the songs and the folders below a folder, as small
/// icons and numbers. Folders are left out when there are none. A hidden
/// folder gets the "Hidden" tag after the counts. Read out as a sentence.
class FolderCountsLine extends StatelessWidget {
  const FolderCountsLine({super.key, required this.folder, this.style});

  final FolderNode folder;
  final TextStyle? style;

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
    final counts = context.l10n.foldersCounts(folder.songs, folder.subfolders);
    return Semantics(
      label: folder.hidden
          ? '$counts, ${context.l10n.foldersHiddenLabel}'
          : counts,
      excludeSemantics: true,
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          count(AppIcons.musicNoteOutlined, folder.songs),
          if (folder.subfolders > 0)
            count(AppIcons.folderOutlined, folder.subfolders),
          if (folder.hidden)
            HiddenLabel(
              style: textStyle?.copyWith(fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }
}
