import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../../../shared/widgets/menu_keyboard_region.dart';

/// What the menu of a folder can do, on all the songs below it.
enum FolderAction {
  play,
  shuffle,
  playNext,
  addToQueue,
  addToPlaylist,
  createPlaylist,
}

FolderAction _queue(QueueAction action) => switch (action) {
  QueueAction.playNext => FolderAction.playNext,
  QueueAction.addToQueue => FolderAction.addToQueue,
  QueueAction.addToPlaylist => FolderAction.addToPlaylist,
};

/// The menu rows: Play and Shuffle when [withPlay] (a page header has them
/// as buttons already), the queue rows and Create playlist.
List<PopupMenuEntry<FolderAction>> folderMenuItems(
  BuildContext context, {
  required bool withPlay,
}) {
  final l10n = context.l10n;
  return [
    if (withPlay) ...[
      menuRow(FolderAction.play, AppIcons.play, l10n.albumsPlay),
      menuRow(FolderAction.shuffle, AppIcons.shuffle, l10n.libraryShuffle),
    ],
    ...queueActionItems(context, _queue),
    menuRow(
      FolderAction.createPlaylist,
      AppIcons.newPlaylist,
      l10n.foldersCreatePlaylist,
    ),
  ];
}

/// Opens the folder menu at the pointer on a right click or a long press of
/// [child], or at the row from the keyboard (Menu key, Shift+F10), and
/// reports the chosen action to [onAction].
class FolderActionsRegion extends StatelessWidget {
  const FolderActionsRegion({
    super.key,
    required this.onAction,
    required this.child,
  });

  final ValueChanged<FolderAction> onAction;
  final Widget child;

  Future<void> _open(BuildContext context, Offset position) async {
    final action = await showMenu<FolderAction>(
      context: context,
      position: menuPositionAt(context, position),
      items: folderMenuItems(context, withPlay: true),
    );
    if (action != null) onAction(action);
  }

  @override
  Widget build(BuildContext context) => MenuKeyboardRegion(
    onOpen: (position) => _open(context, position),
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (details) => _open(context, details.globalPosition),
      onLongPressStart: (details) => _open(context, details.globalPosition),
      child: child,
    ),
  );
}

/// The "more" button of a folder page, next to its Play and Shuffle buttons.
class FolderActionsButton extends StatelessWidget {
  const FolderActionsButton({super.key, required this.onSelected});

  final ValueChanged<FolderAction> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<FolderAction>(
    tooltip: context.l10n.queueActionsTooltip,
    icon: const Icon(AppIcons.more),
    onSelected: onSelected,
    itemBuilder: (context) => folderMenuItems(context, withPlay: false),
  );
}
