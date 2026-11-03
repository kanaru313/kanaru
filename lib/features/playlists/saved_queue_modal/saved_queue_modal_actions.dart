import '../../../l10n/app_localizations.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/m3u/m3u_export_actions.dart';
import '../../../shared/widgets/context_modal/context_modal_spec.dart';
import 'saved_queue_modal_data.dart';

/// The rows of the actions page in three groups (Go to queue; play and copy
/// actions; Delete queue); the footer's queue buttons are not here. While the
/// head loads, or when the queue is gone, the rows that act are greyed out;
/// when nothing in it can play, Play all says so.
List<List<ContextModalAction>> savedQueueModalSections(
  AppLocalizations l10n,
  SavedQueueModalData data,
  SavedQueueModalHandlers h,
) {
  final playable = data.hasPlayable;
  return [
    [
      if (data.showGoTo)
        ContextModalAction(
          id: 'go-to-playlist',
          icon: AppIcons.playlistOutlined,
          label: l10n.queueModalGoTo,
          subtitle: data.playlist.name,
          enabled: !data.gone,
          onTap: contextModalCloseThen(h.goToQueue),
        ),
    ],
    [
      ContextModalAction(
        id: 'play-all',
        icon: AppIcons.play,
        label: l10n.albumModalPlayAll,
        subtitle: !playable && !data.gone && data.load != null
            ? l10n.queueHistoryNothingToPlay
            : null,
        enabled: playable,
        onTap: contextModalCloseThen(h.play),
      ),
      ContextModalAction(
        id: 'shuffle',
        icon: AppIcons.shuffle,
        label: l10n.libraryShuffle,
        enabled: playable,
        onTap: contextModalCloseThen(h.shuffle),
      ),
      ContextModalAction(
        id: 'add-to-playlist',
        icon: AppIcons.addToPlaylist,
        label: l10n.playlistAddTo,
        subtitle: l10n.playlistCopyHint(data.playlist.entryCount),
        // Copies every entry, but only when something can play.
        enabled: playable,
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
        id: 'delete',
        icon: AppIcons.deleteOutline,
        label: l10n.queueModalDelete,
        subtitle: l10n.queueModalDeleteHint,
        destructive: true,
        enabled: !data.gone,
        onTap: h.delete,
      ),
    ],
  ];
}

/// The rows of the Advanced page in three groups: Add all to Favorites; the
/// two M3U exports; Remove missing songs, which shows only when the count
/// read when the modal opened is above zero.
List<List<ContextModalAction>> savedQueueModalAdvancedSections(
  AppLocalizations l10n,
  SavedQueueModalData data,
  SavedQueueModalHandlers h,
) {
  final missing = data.missing;
  return [
    [
      ContextModalAction(
        id: 'add-all-to-favorites',
        icon: AppIcons.favoriteOutline,
        label: l10n.albumModalAddAllToFavorites,
        enabled: data.hasPlayable,
        onTap: contextModalCloseThen(h.addAllToFavorites),
      ),
    ],
    [
      m3uExportAction(
        l10n,
        enabled: data.hasEntries,
        exportAbsolute: h.exportAbsolute,
        exportRelative: h.exportRelative,
      ),
    ],
    [
      if (missing > 0)
        ContextModalAction(
          id: 'remove-missing',
          icon: AppIcons.removeMissing,
          label: l10n.playlistRemoveMissing,
          subtitle: l10n.playlistRemoveMissingHint(missing),
          enabled: !data.gone,
          onTap: h.removeMissing,
        ),
    ],
  ];
}
