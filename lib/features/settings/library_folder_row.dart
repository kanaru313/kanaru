import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';

/// How long the remove button takes to fade in or out.
const _fadeDuration = Duration(milliseconds: 100);

/// One library folder with a trash button that removes it from the library.
///
/// The button shows while the pointer is over the row or the keyboard focus
/// is on it. It stays in the tree when hidden, so the row does not reflow
/// and Tab still reaches it (focus then shows it). A folder that is gone
/// (an unplugged drive) is greyed and struck through, says so, and keeps a
/// red trash button visible: there is nothing left to do with it but remove
/// it.
class LibraryFolderRow extends StatefulWidget {
  const LibraryFolderRow({
    super.key,
    required this.path,
    required this.missing,
    required this.enabled,
    required this.onRemove,
  });

  final String path;
  final bool missing;

  /// `false` while another folder action is running or the library is
  /// unavailable.
  final bool enabled;
  final VoidCallback onRemove;

  @override
  State<LibraryFolderRow> createState() => _LibraryFolderRowState();
}

class _LibraryFolderRowState extends State<LibraryFolderRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final missing = widget.missing;
    final pathStyle = missing
        ? theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.38),
            decoration: TextDecoration.lineThrough,
          )
        : theme.textTheme.bodyLarge;
    final fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _fadeDuration;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      // Only reports focus inside the row: it is no Tab stop itself.
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: ListTile(
          leading: Icon(missing ? AppIcons.folderOff : AppIcons.folderOutlined),
          title: Tooltip(
            message: widget.path,
            child: Text(
              widget.path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: pathStyle,
            ),
          ),
          subtitle: missing ? Text(l10n.settingsFolderMissing) : null,
          trailing: AnimatedOpacity(
            opacity: missing || _hovered || _focused ? 1 : 0,
            duration: fade,
            child: IconButton(
              icon: const Icon(AppIcons.deleteOutline),
              tooltip: l10n.settingsRemoveFolder,
              color: missing ? colors.error : colors.onSurface,
              onPressed: widget.enabled ? widget.onRemove : null,
            ),
          ),
        ),
      ),
    );
  }
}
