import '../../../core/database/history_rows.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/m3u/m3u_export_actions.dart';
import '../../../shared/widgets/context_modal/context_modal_spec.dart';
import 'history_page_modal_data.dart';

/// The rows of the page in three groups: Play all and Shuffle; Add to
/// playlist, Most played and Export as M3U (last played first); Clear history.
/// The footer's queue buttons are not here. The song actions are enabled by
/// the number of listens, not songs: the songs still in the library are only
/// known when a row is tapped, which then says so when there are none. Clear
/// needs a recorder, a listen, and no clear [clearing] already.
List<List<ContextModalAction>> historyPageModalSections(
  AppLocalizations l10n,
  HistoryOverview? overview,
  HistoryPageModalHandlers h, {
  bool clearing = false,
}) => [
  [
    ContextModalAction(
      id: 'play-all',
      icon: AppIcons.play,
      label: l10n.albumModalPlayAll,
      enabled: _hasPlays(overview),
      onTap: contextModalCloseThen(h.play),
    ),
    ContextModalAction(
      id: 'shuffle',
      icon: AppIcons.shuffle,
      label: l10n.libraryShuffle,
      enabled: _hasPlays(overview),
      onTap: contextModalCloseThen(h.shuffle),
    ),
  ],
  [
    ContextModalAction(
      id: 'add-to-playlist',
      icon: AppIcons.addToPlaylist,
      label: l10n.playlistAddTo,
      subtitle: l10n.historyNewPlaylistSuggests(l10n.navHistory),
      enabled: _hasPlays(overview),
      onTap: contextModalCloseThen(h.addToPlaylist),
    ),
    ContextModalAction(
      id: 'most-played',
      icon: AppIcons.mostPlayedOutlined,
      label: l10n.navMostPlayed,
      subtitle: l10n.historyMostPlayedHint,
      onTap: contextModalCloseThen(h.openMostPlayed),
    ),
    m3uExportAction(
      l10n,
      enabled: _hasPlays(overview),
      detail: l10n.historyLastPlayedFirst,
      exportAbsolute: h.exportAbsolute,
      exportRelative: h.exportRelative,
    ),
  ],
  [
    ContextModalAction(
      id: 'clear',
      icon: AppIcons.clearAll,
      label: l10n.historyClear,
      subtitle: l10n.historyClearHint,
      destructive: true,
      enabled: h.clear != null && !clearing && _hasPlays(overview),
      onTap: h.clear,
    ),
  ],
];

bool _hasPlays(HistoryOverview? overview) =>
    overview != null && overview.plays > 0;
