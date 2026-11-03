import '../../../l10n/app_localizations.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/m3u/m3u_export_actions.dart';
import '../../../shared/widgets/context_modal/context_modal_spec.dart';
import 'history_day_modal_data.dart';

/// The rows of the page in three groups: Play all and Shuffle; Add to
/// playlist, Open in Most played and Export as M3U; Remove. The footer's queue buttons are not here. Everything
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
    ],
    [
      ContextModalAction(
        id: 'add-to-playlist',
        icon: AppIcons.addToPlaylist,
        label: l10n.playlistAddTo,
        subtitle: l10n.historyNewPlaylistSuggests(date),
        enabled: data.canQueue,
        onTap: contextModalCloseThen(h.addToPlaylist),
      ),
      ContextModalAction(
        id: 'open-in-most-played',
        icon: AppIcons.mostPlayedOutlined,
        label: l10n.historyOpenInMostPlayed,
        subtitle: date,
        onTap: contextModalCloseThen(h.openInMostPlayed),
      ),
      m3uExportAction(
        l10n,
        enabled: data.canQueue,
        detail: l10n.historyOrderLastPlayedFirst(data.songs),
        exportAbsolute: h.exportAbsolute,
        exportRelative: h.exportRelative,
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
