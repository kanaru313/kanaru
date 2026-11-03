import 'package:material_ui/material_ui.dart';

import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/context_modal/context_modal_header.dart';
import '../folder_art.dart';
import '../folder_tree.dart';
import 'folder_modal_data.dart';

const double _artSize = 64;

/// Top of the folder modal: the folder art, the folder name, and
/// "N songs • M subfolders • length".
///
/// With [onTap] (Go to folder, which closes the modal first) the whole header
/// is one button that does not take keyboard focus: the first row does. It is
/// null on the page of the folder itself.
class FolderModalHeader extends StatelessWidget {
  const FolderModalHeader({
    super.key,
    required this.folder,
    required this.data,
    this.direct = false,
    this.onTap,
  });

  final FolderNode folder;
  final FolderModalData data;
  final bool direct;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ContextModalHeader(
      leading: FolderArt(folder: folder, size: _artSize, direct: direct),
      lines: [
        contextModalHeaderLine(folder.name, theme.textTheme.titleMedium),
        contextModalHeaderLine(
          data.statsLine(l10n),
          theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      onTap: onTap,
      tapHint: l10n.songModalGoToFolder,
    );
  }
}
