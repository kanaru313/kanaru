import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../../../shared/widgets/menu_keyboard_region.dart';

/// What the menu of a folder can do, on all the songs below it (or only the
/// songs directly in it in the flat view).
enum FolderAction {
  play,
  playAllBelow,
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
/// as buttons already), "Play all below" when [withPlayAllBelow] (the flat
/// view of a folder with subfolders), the queue rows and Create playlist
/// unless [withSongActions] is off (a flat folder without songs of its own:
/// they would read nothing).
List<PopupMenuEntry<FolderAction>> folderMenuItems(
  BuildContext context, {
  required bool withPlay,
  bool withPlayAllBelow = false,
  bool withSongActions = true,
}) {
  final l10n = context.l10n;
  return [
    if (withPlay) ...[
      menuRow(FolderAction.play, AppIcons.play, l10n.albumsPlay),
      menuRow(FolderAction.shuffle, AppIcons.shuffle, l10n.libraryShuffle),
    ],
    if (withPlayAllBelow)
      menuRow(
        FolderAction.playAllBelow,
        AppIcons.playlistPlay,
        l10n.foldersPlayAllBelow,
      ),
    if (withSongActions) ...[
      ...queueActionItems(context, _queue),
      menuRow(
        FolderAction.createPlaylist,
        AppIcons.newPlaylist,
        l10n.foldersCreatePlaylist,
      ),
    ],
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
    this.withPlayAllBelow = false,
  });

  final ValueChanged<FolderAction> onAction;

  /// Whether the menu has the "Play all below" row.
  final bool withPlayAllBelow;
  final Widget child;

  Future<void> _open(BuildContext context, Offset position) async {
    final action = await showMenu<FolderAction>(
      context: context,
      position: menuPositionAt(context, position),
      items: folderMenuItems(
        context,
        withPlay: true,
        withPlayAllBelow: withPlayAllBelow,
      ),
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
  const FolderActionsButton({
    super.key,
    required this.onSelected,
    this.withPlayAllBelow = false,
    this.withSongActions = true,
  });

  final ValueChanged<FolderAction> onSelected;

  /// Whether the menu has the "Play all below" row.
  final bool withPlayAllBelow;

  /// Whether the menu has the rows on the folder's own songs. With neither
  /// kind of row the button is left out.
  final bool withSongActions;

  @override
  Widget build(BuildContext context) => !withSongActions && !withPlayAllBelow
      ? const SizedBox.shrink()
      : PopupMenuButton<FolderAction>(
          tooltip: context.l10n.queueActionsTooltip,
          icon: const Icon(AppIcons.more),
          onSelected: onSelected,
          itemBuilder: (context) => folderMenuItems(
            context,
            withPlay: false,
            withPlayAllBelow: withPlayAllBelow,
            withSongActions: withSongActions,
          ),
        );
}
