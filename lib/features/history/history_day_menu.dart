import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/queue_actions_menu.dart';

/// What the menu of a day bar can do.
enum HistoryDayChoice { playAll, playNext, addToQueue, createPlaylist, delete }

/// Opens the day menu with its corner at [position] (global). The four rows
/// that use the day's songs are greyed out when [canQueue] is false (none of
/// the day's plays has a song in the library). Returns null when dismissed.
Future<HistoryDayChoice?> showHistoryDayMenu(
  BuildContext context,
  Offset position, {
  required bool canQueue,
}) {
  final l10n = context.l10n;
  return showMenu<HistoryDayChoice>(
    context: context,
    position: menuPositionAt(context, position),
    items: [
      menuRow(
        HistoryDayChoice.playAll,
        AppIcons.play,
        l10n.historyPlayAll,
        enabled: canQueue,
      ),
      menuRow(
        HistoryDayChoice.playNext,
        AppIcons.playlistPlay,
        l10n.queuePlayNext,
        enabled: canQueue,
      ),
      menuRow(
        HistoryDayChoice.addToQueue,
        AppIcons.addToQueue,
        l10n.queueAddToQueue,
        enabled: canQueue,
      ),
      menuRow(
        HistoryDayChoice.createPlaylist,
        AppIcons.newPlaylist,
        l10n.historyDayCreatePlaylist,
        enabled: canQueue,
      ),
      const PopupMenuDivider(),
      menuRow(
        HistoryDayChoice.delete,
        AppIcons.deleteOutline,
        l10n.historyDayDelete,
      ),
    ],
  );
}
