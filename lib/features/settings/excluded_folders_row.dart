import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';

/// One excluded folder with a button that stops excluding it.
///
/// A folder that no longer counts ([note] set: it is gone, or not below a
/// music folder any more) is greyed and says why; the button stays, as it is
/// the only thing left to do with it. Stopping an exclusion deletes nothing,
/// so there is no confirmation.
class ExcludedFolderRow extends StatelessWidget {
  const ExcludedFolderRow({
    super.key,
    required this.path,
    required this.note,
    required this.enabled,
    required this.onRemove,
  });

  final String path;

  /// Why the exclusion has no effect; `null` when it applies.
  final String? note;

  /// `false` while another action runs or the library is unavailable.
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inactive = note != null;
    return ListTile(
      leading: Icon(inactive ? AppIcons.folderOff : AppIcons.folderOutlined),
      title: Tooltip(
        message: path,
        child: Text(
          path,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: inactive
              ? theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                )
              : theme.textTheme.bodyLarge,
        ),
      ),
      subtitle: note == null ? null : Text(note!),
      trailing: IconButton(
        icon: const Icon(AppIcons.deleteOutline),
        tooltip: context.l10n.excludedFoldersRemove,
        onPressed: enabled ? onRemove : null,
      ),
    );
  }
}
