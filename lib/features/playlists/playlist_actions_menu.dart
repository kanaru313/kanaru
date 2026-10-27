import 'package:material_ui/material_ui.dart';

import '../../core/m3u/m3u_write.dart' show M3uPathStyle;
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/queue_actions_menu.dart';

/// What the menu of a playlist page can do besides the queue actions.
enum _EditAction { rename, delete, exportAbsolute, exportRelative }

/// The value of a menu row: an edit action or a queue action.
typedef _Choice = Object;

/// The "more" button of a playlist page. Rows, in sections split by a
/// divider: Rename and the two M3U exports; the queue actions; Delete. A
/// section shows only when its callbacks are given, and a divider only
/// between two shown sections. Check [hasItems] before showing it.
class PlaylistActionsMenu extends StatelessWidget {
  const PlaylistActionsMenu({
    super.key,
    this.onQueueAction,
    this.onRename,
    this.onDelete,
    this.onExport,
  });

  /// Null leaves the queue rows out (nothing to enqueue).
  final ValueChanged<QueueAction>? onQueueAction;

  /// Null leaves the row out (the Favorites playlist, a saved queue).
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  /// Saves the playlist as an M3U file with paths of the given style; null
  /// leaves the two export rows out.
  final ValueChanged<M3uPathStyle>? onExport;

  /// Whether any row would show; without one the caller leaves the button out.
  bool get hasItems =>
      onQueueAction != null ||
      onRename != null ||
      onDelete != null ||
      onExport != null;

  List<PopupMenuEntry<_Choice>> _items(BuildContext context) {
    final l10n = context.l10n;
    final sections = <List<PopupMenuEntry<_Choice>>>[
      [
        if (onRename != null)
          menuRow<_Choice>(
            _EditAction.rename,
            AppIcons.edit,
            l10n.playlistRename,
          ),
        if (onExport != null) ...[
          menuRow<_Choice>(
            _EditAction.exportAbsolute,
            AppIcons.exportPlaylist,
            l10n.playlistM3uExportAbsolute,
          ),
          menuRow<_Choice>(
            _EditAction.exportRelative,
            AppIcons.exportPlaylist,
            l10n.playlistM3uExportRelative,
          ),
        ],
      ],
      if (onQueueAction != null)
        queueActionItems<_Choice>(context, (action) => action),
      [
        if (onDelete != null)
          menuRow<_Choice>(
            _EditAction.delete,
            AppIcons.deleteOutline,
            l10n.playlistDelete,
          ),
      ],
    ].where((section) => section.isNotEmpty).toList();

    return [
      for (final (i, section) in sections.indexed) ...[
        if (i > 0) const PopupMenuDivider(),
        ...section,
      ],
    ];
  }

  void _select(_Choice choice) {
    switch (choice) {
      case QueueAction():
        onQueueAction?.call(choice);
      case _EditAction.rename:
        onRename?.call();
      case _EditAction.delete:
        onDelete?.call();
      case _EditAction.exportAbsolute:
        onExport?.call(M3uPathStyle.absolute);
      case _EditAction.exportRelative:
        onExport?.call(M3uPathStyle.relative);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Choice>(
      tooltip: context.l10n.playlistActions,
      icon: const Icon(AppIcons.more),
      onSelected: _select,
      itemBuilder: _items,
    );
  }
}
