import 'dart:async';

import '../../../core/m3u/m3u_write.dart' show M3uPathStyle;
import '../../../core/player/player_service.dart';
import '../../../shared/m3u/m3u_export_flow.dart';
import '../../../shared/m3u/m3u_save_picker.dart';
import '../../../shared/track_menu_actions.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/context_modal/context_modal_nav.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../history_delete_undo.dart';
import '../history_plays_version.dart';
import '../history_range.dart';
import '../history_routes.dart';
import '../most_played_range.dart';
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
    required this.version,
  });

  final HistoryDayModalData data;

  /// "Now" on the page's clock, for Today and Yesterday.
  final DateTime now;
  final TrackMenuRunner runner;

  /// Captured while the day bar was on screen: the notifier is auto-dispose,
  /// so it cannot be read again after the page is left.
  final HistoryPlaysVersion version;

  /// True while the Remove confirm is open above the modal: a second tap
  /// meanwhile must not stack another one.
  bool dialogOpen = false;

  /// The full date, which names the day in snackbars, the picker and the
  /// export file.
  String get label => runner.l10n.historyDayDate(data.day);

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

  void addToPlaylist() => runner.queueHost?.enqueueLoaded(
    QueueAction.addToPlaylist,
    data.tracks,
    label,
    suggestedName: label,
  );

  Future<void> export(M3uPathStyle style) {
    final messenger = runner.messenger;
    if (messenger == null) return Future.value();
    return exportM3uWith(
      save: runner.container.read(m3uSavePickerProvider),
      messenger: messenger,
      l10n: runner.l10n,
      navigator: runner.rootNavigator,
      name: label,
      style: style,
      readEntries: () async => data.exportEntries,
    );
  }

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
    final navigator = runner.rootNavigator;
    final db = runner.db;
    final messenger = runner.messenger;
    if (navigator == null ||
        !navigator.mounted ||
        db == null ||
        messenger == null ||
        dialogOpen) {
      return;
    }
    final l10n = runner.l10n;
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
    await runner.container
        .read(historyDeleteUndoProvider)
        .deleteMany(
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
    addToPlaylist: addToPlaylist,
    openInMostPlayed: openInMostPlayed,
    exportAbsolute: () => unawaited(export(M3uPathStyle.absolute)),
    exportRelative: () => unawaited(export(M3uPathStyle.relative)),
    remove: (nav) => unawaited(remove(nav)),
  );
}
