import '../../../l10n/app_localizations.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/m3u/m3u_export_actions.dart';
import '../../../shared/widgets/context_modal/context_modal_spec.dart';
import 'most_played_modal_data.dart';

/// The rows in three groups: Play all and Shuffle; Add to playlist and Add all to Favorites; the two
/// M3U exports (absolute and relative paths, rank order). [songs] is the
/// number of library songs the rows act on; none disables every row. The
/// footer's queue buttons are not here.
List<List<ContextModalAction>> mostPlayedModalSections(
  AppLocalizations l10n,
  String rangeText,
  int songs,
  MostPlayedModalHandlers h,
) {
  final order = l10n.historyOrderRank(songs);
  final enabled = songs > 0;
  return [
    [
      ContextModalAction(
        id: 'play-all',
        icon: AppIcons.play,
        label: l10n.albumModalPlayAll,
        enabled: enabled,
        onTap: contextModalCloseThen(h.play),
      ),
      ContextModalAction(
        id: 'shuffle',
        icon: AppIcons.shuffle,
        label: l10n.libraryShuffle,
        enabled: enabled,
        onTap: contextModalCloseThen(h.shuffle),
      ),
    ],
    [
      ContextModalAction(
        id: 'add-to-playlist',
        icon: AppIcons.addToPlaylist,
        label: l10n.playlistAddTo,
        subtitle: l10n.historyNewPlaylistSuggests(
          l10n.historyTopPlaylistName(rangeText),
        ),
        enabled: enabled,
        onTap: contextModalCloseThen(h.addToPlaylist),
      ),
      ContextModalAction(
        id: 'add-all-to-favorites',
        icon: AppIcons.favoriteOutline,
        label: l10n.albumModalAddAllToFavorites,
        subtitle: l10n.albumsSongCount(songs),
        enabled: enabled,
        onTap: contextModalCloseThen(h.addToFavorites),
      ),
    ],
    [
      ...m3uExportActions(
        l10n,
        enabled: enabled,
        detail: order,
        exportAbsolute: h.exportAbsolute,
        exportRelative: h.exportRelative,
      ),
    ],
  ];
}
