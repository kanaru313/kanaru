import '../../../l10n/app_localizations.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/m3u/m3u_export_actions.dart';
import '../../../shared/widgets/context_modal/context_modal_spec.dart';
import '../playlist_display_name.dart';
import 'playlist_modal_data.dart';

/// The rows of the actions page in three groups (Go to playlist; play and
/// copy actions; Edit and Delete); the footer's queue buttons are not here.
/// While the head loads, or when the playlist is gone, the rows that act are
/// greyed out; Favorites has no Edit and no Delete. A saved queue has Go to
/// queue and Delete queue, no Edit, and tells when nothing in it can play.
List<List<ContextModalAction>> playlistModalSections(
  AppLocalizations l10n,
  PlaylistModalData data,
  PlaylistModalHandlers h,
) {
  final name = playlistDisplayName(data.playlist, l10n);
  final playable = data.hasPlayable;
  final queue = data.savedQueue;
  return [
    [
      if (data.showGoTo)
        ContextModalAction(
          id: 'go-to-playlist',
          icon: AppIcons.playlistOutlined,
          label: queue ? l10n.queueModalGoTo : l10n.playlistGoTo,
          subtitle: name,
          enabled: !data.gone,
          onTap: contextModalCloseThen(h.goToPlaylist),
        ),
    ],
    [
      ContextModalAction(
        id: 'play-all',
        icon: AppIcons.play,
        label: l10n.albumModalPlayAll,
        subtitle: queue && !playable && !data.gone && data.load != null
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
        // A saved queue copies every entry, but only when something can play.
        enabled: queue ? playable : data.hasEntries,
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
      if (queue)
        ContextModalAction(
          id: 'delete',
          icon: AppIcons.deleteOutline,
          label: l10n.queueModalDelete,
          subtitle: l10n.queueModalDeleteHint,
          destructive: true,
          enabled: !data.gone,
          onTap: h.delete,
        )
      else if (!data.isFavorites) ...[
        ContextModalAction(
          id: 'edit',
          icon: AppIcons.edit,
          label: l10n.playlistEditAction,
          subtitle: l10n.playlistEditActionHint,
          enabled: !data.gone,
          onTap: (_) => h.edit(),
        ),
        ContextModalAction(
          id: 'delete',
          icon: AppIcons.deleteOutline,
          label: l10n.playlistDelete,
          subtitle: l10n.playlistDeleteHint,
          destructive: true,
          enabled: !data.gone,
          onTap: h.delete,
        ),
      ],
    ],
  ];
}

/// The rows of the Advanced page in four groups: Add all to Favorites and
/// Duplicate; the two M3U exports; the clean-ups, which show only when the
/// counts read when the modal opened are above zero.
List<List<ContextModalAction>> playlistModalAdvancedSections(
  AppLocalizations l10n,
  PlaylistModalData data,
  PlaylistModalHandlers h,
) {
  final name = playlistDisplayName(data.playlist, l10n);
  final stats = data.stats;
  final queue = data.savedQueue;
  final repeats = data.isFavorites || queue ? 0 : stats?.repeats ?? 0;
  final missing = stats?.missing ?? 0;
  return [
    [
      if (!data.isFavorites)
        ContextModalAction(
          id: 'add-all-to-favorites',
          icon: AppIcons.favoriteOutline,
          label: l10n.albumModalAddAllToFavorites,
          enabled: data.hasPlayable,
          onTap: contextModalCloseThen(h.addAllToFavorites),
        ),
      if (!queue)
        ContextModalAction(
          id: 'duplicate',
          icon: AppIcons.duplicatePlaylist,
          label: l10n.playlistDuplicate,
          subtitle: l10n.playlistCopyName(name),
          enabled: !data.gone,
          onTap: contextModalCloseThen(h.duplicate),
        ),
    ],
    [
      ...m3uExportActions(
        l10n,
        enabled: data.hasEntries,
        exportAbsolute: h.exportAbsolute,
        exportRelative: h.exportRelative,
      ),
    ],
    [
      if (repeats > 0)
        ContextModalAction(
          id: 'remove-duplicates',
          icon: AppIcons.removeDuplicates,
          label: l10n.playlistRemoveDuplicates,
          subtitle: l10n.playlistRemoveDuplicatesHint(repeats),
          enabled: !data.gone,
          onTap: contextModalCloseThen(h.removeDuplicates),
        ),
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
