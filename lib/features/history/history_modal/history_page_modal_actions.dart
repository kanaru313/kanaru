import 'package:flutter/widgets.dart' show VoidCallback;

import '../../../core/database/history_rows.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/context_modal/context_modal_nav.dart';
import '../../../shared/widgets/context_modal/context_modal_spec.dart';
import '../../../shared/widgets/library_row.dart' show joinRowDetails;

/// What the History modal's rows do. Each runs after the modal has closed
/// except [openAdvanced], which pushes the page.
class HistoryPageModalHandlers {
  const HistoryPageModalHandlers({
    required this.addToPlaylist,
    required this.openMostPlayed,
    required this.exportAbsolute,
    required this.exportRelative,
    this.clear,
    this.openAdvanced,
  });

  final VoidCallback addToPlaylist;
  final VoidCallback openMostPlayed;
  final VoidCallback exportAbsolute;
  final VoidCallback exportRelative;

  /// Asks which part to clear (above the modal), then closes it; `null`
  /// without a recorder to run the delete.
  final void Function(ContextModalNav nav)? clear;
  final void Function(ContextModalNav nav)? openAdvanced;
}

/// The rows of the first page: Add to playlist, Most played, Advanced. The
/// footer's queue buttons are not here. The song actions are enabled by the
/// number of listens, not songs: the songs still in the library are only
/// known when a row is tapped, which then says so when there are none.
List<List<ContextModalAction>> historyPageModalSections(
  AppLocalizations l10n,
  HistoryOverview? overview,
  HistoryPageModalHandlers h,
) => [
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
    ContextModalAction(
      id: 'advanced',
      icon: AppIcons.advanced,
      label: l10n.songModalAdvanced,
      opensPage: true,
      onTap: h.openAdvanced,
    ),
  ],
];

/// The rows of the Advanced page in two groups: the two M3U exports
/// (absolute and relative paths, last played first); Clear history. Clear
/// needs a recorder, a listen, and no clear [clearing] already.
List<List<ContextModalAction>> historyPageModalAdvancedSections(
  AppLocalizations l10n,
  HistoryOverview? overview,
  HistoryPageModalHandlers h, {
  bool clearing = false,
}) {
  final order = l10n.historyLastPlayedFirst;
  return [
    [
      ContextModalAction(
        id: 'export-absolute',
        icon: AppIcons.exportFile,
        label: l10n.playlistExportM3u,
        subtitle: joinRowDetails([l10n.playlistExportAbsoluteHint, order]),
        enabled: _hasPlays(overview),
        onTap: contextModalCloseThen(h.exportAbsolute),
      ),
      ContextModalAction(
        id: 'export-relative',
        icon: AppIcons.exportFile,
        label: l10n.playlistExportM3u,
        subtitle: joinRowDetails([l10n.playlistExportRelativeHint, order]),
        enabled: _hasPlays(overview),
        onTap: contextModalCloseThen(h.exportRelative),
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
}

bool _hasPlays(HistoryOverview? overview) =>
    overview != null && overview.plays > 0;
