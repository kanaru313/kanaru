import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';

/// Which kinds of entries a folder page shows.
enum FolderFilter { all, folders, songs }

/// The chips `All · Folders N · Songs M` over a folder page that holds both
/// subfolders and songs. The row scrolls sideways so large text or a long
/// translation never overflows.
class FolderFilterChips extends StatelessWidget {
  const FolderFilterChips({
    super.key,
    required this.selected,
    required this.folderCount,
    required this.songCount,
    required this.onSelected,
  });

  final FolderFilter selected;
  final int folderCount;
  final int songCount;
  final ValueChanged<FolderFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      FolderFilter.all: l10n.foldersFilterAll,
      FolderFilter.folders: l10n.foldersSectionFolders(folderCount),
      FolderFilter.songs: l10n.foldersSectionSongs(songCount),
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: Row(
        children: [
          for (final e in labels.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(e.value),
                selected: selected == e.key,
                onSelected: (_) => onSelected(e.key),
              ),
            ),
        ],
      ),
    );
  }
}
