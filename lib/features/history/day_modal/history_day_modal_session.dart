import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart' show LibraryDatabase;
import '../../../core/m3u/m3u_write.dart' show M3uPathStyle;
import '../../../core/player/player_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/m3u/m3u_export_flow.dart';
import '../../../shared/m3u/m3u_save_picker.dart';
import '../../../shared/track_menu_actions.dart';
import '../../../shared/widgets/add_to_playlist/add_to_playlist_flow.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/context_modal/context_modal_nav.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../history_delete_undo.dart';
import '../history_plays_version.dart';
import '../history_range.dart';
import '../history_routes.dart';
import '../most_played_range.dart';
import 'history_day_modal_actions.dart';
import 'history_day_modal_data.dart';

/// What one open Day modal holds: the snapshot of the day and everything its
/// actions need from the widget tree, captured before the modal opened. The
/// day bar may be rebuilt away (or the page left) while the modal is open, so
/// nothing here refers to its own `BuildContext`. Its lifetime is one open
/// modal.
class HistoryDayModalSession {
  HistoryDayModalSession({
    required this.data,
    required this.now,
    required this.runner,
    required this.db,
    required this.l10n,
    required this.messenger,
    required this.rootNavigator,
    required this.save,
    required this.version,
    required this.undo,
  });

  final HistoryDayModalData data;

  /// "Now" on the page's clock, for Today and Yesterday.
  final DateTime now;
  final TrackMenuRunner runner;
  final LibraryDatabase db;
  final AppLocalizations l10n;
  final ScaffoldMessengerState messenger;
  final NavigatorState? rootNavigator;
  final M3uSavePicker save;
  final HistoryPlaysVersion version;
  final HistoryDeleteUndo undo;

  /// True while the Remove confirm is open above the modal: a second tap
  /// meanwhile must not stack another one.
  bool dialogOpen = false;

  /// The full date, which names the day in snackbars, the picker and the
  /// export file.
  String get label => l10n.historyDayDate(data.day);

  /// Runs a queue action of the footer on the snapshot's songs.
  void queue(QueueAction action) =>
      runner.queueHost?.enqueueLoaded(action, data.tracks, label);

  void play({bool shuffle = false}) {
    final player = runner.container.read(playerServiceProvider.notifier);
    unawaited(
      shuffle
          ? player.openShuffled(data.tracks)
          : player.openTracks(data.tracks, start: 0),
    );
  }

  Future<void> addToPlaylist() async {
    final navigator = rootNavigator;
    if (navigator == null || !navigator.mounted) return;
    await addTracksToPlaylistWith(
      db: db,
      messenger: messenger,
      l10n: l10n,
      dialogContext: navigator.context,
      // Library songs carry their file path as uri.
      readPaths: () async => [for (final t in data.tracks) t.uri],
      label: label,
      suggestedName: label,
    );
  }

  Future<void> export(M3uPathStyle style) => exportM3uWith(
    save: save,
    messenger: messenger,
    l10n: l10n,
    navigator: rootNavigator,
    name: label,
    style: style,
    readEntries: () async => data.exportEntries,
  );

  /// Shows the day's ranking: Most played on a one-day custom range.
  void openInMostPlayed() {
    final day = data.day;
    runner.container
        .read(mostPlayedRangeProvider.notifier)
        .set(
          HistoryRangeState(
            preset: HistoryRangePreset.custom,
            customStart: day,
            customEndInclusive: day,
          ),
        );
    runner.goTo(mostPlayedPath);
  }

  /// Confirms above the modal (cancel comes back to it), closes the modal and
  /// deletes exactly the snapshot's plays, with the Undo snackbar.
  Future<void> remove(ContextModalNav nav) async {
    final navigator = rootNavigator;
    if (navigator == null || !navigator.mounted || dialogOpen) return;
    dialogOpen = true;
    final bool confirmed;
    try {
      confirmed = await confirmAction(
        navigator.context,
        title: l10n.historyDayRemoveTitle,
        body: l10n.historyDayRemoveBody(data.plays, label),
        confirmLabel: l10n.historyDayDelete,
      );
    } finally {
      dialogOpen = false;
    }
    if (!confirmed) return;
    nav.close();
    await undo.deleteMany(
      db: db,
      messenger: messenger,
      l10n: l10n,
      version: version,
      playIds: data.playIds,
    );
  }

  /// The callbacks the rows call.
  HistoryDayModalHandlers handlers({
    void Function(ContextModalNav nav)? openAdvanced,
  }) => HistoryDayModalHandlers(
    openAdvanced: openAdvanced,
    playAll: play,
    shuffle: () => play(shuffle: true),
    addToPlaylist: () => unawaited(addToPlaylist()),
    openInMostPlayed: openInMostPlayed,
    exportAbsolute: () => unawaited(export(M3uPathStyle.absolute)),
    exportRelative: () => unawaited(export(M3uPathStyle.relative)),
    remove: (nav) => unawaited(remove(nav)),
  );
}
