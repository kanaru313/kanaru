import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/queue_actions_menu.dart';

/// What the menu of a History row can do.
enum HistoryPlayChoice { playNext, addToQueue, addToPlaylist, delete }

/// The queue action a choice stands for, or null for the others.
QueueAction? historyQueueActionOf(HistoryPlayChoice choice) => switch (choice) {
  HistoryPlayChoice.playNext => QueueAction.playNext,
  HistoryPlayChoice.addToQueue => QueueAction.addToQueue,
  HistoryPlayChoice.addToPlaylist => QueueAction.addToPlaylist,
  HistoryPlayChoice.delete => null,
};

/// Opens the row menu with its corner at [position] (global): the queue rows,
/// greyed out when the song is gone from the library ([canQueue] false), then
/// Remove from history. Returns null when it was dismissed.
Future<HistoryPlayChoice?> showHistoryPlayMenu(
  BuildContext context,
  Offset position, {
  required bool canQueue,
}) {
  final l10n = context.l10n;
  return showMenu<HistoryPlayChoice>(
    context: context,
    position: menuPositionAt(context, position),
    items: [
      menuRow(
        HistoryPlayChoice.playNext,
        AppIcons.playlistPlay,
        l10n.queuePlayNext,
        enabled: canQueue,
      ),
      menuRow(
        HistoryPlayChoice.addToQueue,
        AppIcons.addToQueue,
        l10n.queueAddToQueue,
        enabled: canQueue,
      ),
      menuRow(
        HistoryPlayChoice.addToPlaylist,
        AppIcons.addToPlaylist,
        l10n.playlistAddTo,
        enabled: canQueue,
      ),
      const PopupMenuDivider(),
      menuRow(
        HistoryPlayChoice.delete,
        AppIcons.deleteOutline,
        l10n.historyDeletePlay,
      ),
    ],
  );
}
