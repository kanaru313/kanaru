import 'package:flutter/widgets.dart' show VoidCallback;

import '../../../l10n/app_localizations.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/m3u/m3u_export_actions.dart';
import '../../../shared/widgets/context_modal/context_modal_nav.dart';
import '../../../shared/widgets/context_modal/context_modal_spec.dart';
import 'history_day_modal_data.dart';

/// What the Day modal's rows do. Each runs after the modal has closed except
/// [openAdvanced] (pushes the page) and [remove] (confirms above the modal
/// first, then closes it).
class HistoryDayModalHandlers {
  const HistoryDayModalHandlers({
    required this.playAll,
    required this.shuffle,
    required this.addToPlaylist,
    required this.openInMostPlayed,
    required this.exportAbsolute,
    required this.exportRelative,
    required this.remove,
    this.openAdvanced,
  });

  final VoidCallback playAll;
  final VoidCallback shuffle;
  final VoidCallback addToPlaylist;
  final VoidCallback openInMostPlayed;
  final VoidCallback exportAbsolute;
  final VoidCallback exportRelative;
  final void Function(ContextModalNav nav) remove;
  final void Function(ContextModalNav nav)? openAdvanced;
}

/// The rows of the first page in two groups: play and copy actions with
/// Advanced; Remove. The footer's queue buttons are not here. Everything
/// but Remove needs a library song in the snapshot; Remove needs a play.
List<List<ContextModalAction>> historyDayModalSections(
  AppLocalizations l10n,
  HistoryDayModalData data,
  HistoryDayModalHandlers h,
) {
  final date = l10n.historyDayDate(data.day);
  return [
    [
      ContextModalAction(
        id: 'play-all',
        icon: AppIcons.play,
        label: l10n.historyPlayAll,
        subtitle: l10n.historyOrderLastPlayedFirst(data.songs),
        enabled: data.canQueue,
        onTap: contextModalCloseThen(h.playAll),
      ),
      ContextModalAction(
        id: 'shuffle',
        icon: AppIcons.shuffle,
        label: l10n.libraryShuffle,
        enabled: data.canQueue,
        onTap: contextModalCloseThen(h.shuffle),
      ),
      ContextModalAction(
        id: 'add-to-playlist',
        icon: AppIcons.addToPlaylist,
        label: l10n.playlistAddTo,
        subtitle: l10n.historyNewPlaylistSuggests(date),
        enabled: data.canQueue,
        onTap: contextModalCloseThen(h.addToPlaylist),
      ),
      ContextModalAction(
        id: 'advanced',
        icon: AppIcons.advanced,
        label: l10n.songModalAdvanced,
        opensPage: true,
        onTap: h.openAdvanced,
      ),
    ],
    [
      ContextModalAction(
        id: 'remove-day',
        icon: AppIcons.deleteOutline,
        label: l10n.historyDayDelete,
        subtitle: l10n.historyDayRemoveHint(data.plays),
        destructive: true,
        enabled: data.canRemove,
        onTap: h.remove,
      ),
    ],
  ];
}

/// The rows of the Advanced page: Open in Most played, then the two M3U
/// exports (absolute and relative paths) of the day's songs.
List<List<ContextModalAction>> historyDayModalAdvancedSections(
  AppLocalizations l10n,
  HistoryDayModalData data,
  HistoryDayModalHandlers h,
) {
  final order = l10n.historyOrderLastPlayedFirst(data.songs);
  return [
    [
      ContextModalAction(
        id: 'open-in-most-played',
        icon: AppIcons.mostPlayedOutlined,
        label: l10n.historyOpenInMostPlayed,
        subtitle: l10n.historyDayDate(data.day),
        onTap: contextModalCloseThen(h.openInMostPlayed),
      ),
    ],
    [
      ...m3uExportActions(
        l10n,
        enabled: data.canQueue,
        detail: order,
        exportAbsolute: h.exportAbsolute,
        exportRelative: h.exportRelative,
      ),
    ],
  ];
}
