import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

enum _FolderAction { change, remove }

/// One library folder. A folder that is gone (an unplugged drive) is greyed
/// and struck through, says so, and offers a visible trash button instead of
/// the menu: there is nothing left to change it to but a removal.
class LibraryFolderRow extends StatelessWidget {
  const LibraryFolderRow({
    super.key,
    required this.path,
    required this.missing,
    required this.enabled,
    required this.onChange,
    required this.onRemove,
  });

  final String path;
  final bool missing;

  /// `false` while another folder action is running or the library is
  /// unavailable.
  final bool enabled;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final pathStyle = missing
        ? theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.38),
            decoration: TextDecoration.lineThrough,
          )
        : theme.textTheme.bodyLarge;

    return ListTile(
      leading: Icon(
        missing ? Icons.folder_off_outlined : Icons.folder_outlined,
      ),
      title: Tooltip(
        message: path,
        child: Text(
          path,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: pathStyle,
        ),
      ),
      subtitle: missing ? Text(l10n.settingsFolderMissing) : null,
      trailing: missing
          ? IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.settingsRemoveFolder,
              onPressed: enabled ? onRemove : null,
            )
          : PopupMenuButton<_FolderAction>(
              tooltip: l10n.settingsFolderMenu,
              enabled: enabled,
              onSelected: (action) => switch (action) {
                _FolderAction.change => onChange(),
                _FolderAction.remove => onRemove(),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _FolderAction.change,
                  child: Text(l10n.settingsChangeFolder),
                ),
                PopupMenuItem(
                  value: _FolderAction.remove,
                  child: Text(l10n.settingsRemoveFolder),
                ),
              ],
            ),
    );
  }
}
