import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:logging/logging.dart';

import '../../../core/database/history_queries.dart';
import '../../../core/database/library_database.dart' show LibraryDatabase;
import '../../../core/m3u/m3u_write.dart' show M3uExportEntry, M3uPathStyle;
import '../../../core/player/player_service.dart';
import '../../../core/player/track.dart';
import '../../../core/stats/listen_clear_scope.dart';
import '../../../core/stats/listen_recorder.dart';
import '../../../shared/m3u/m3u_export_flow.dart';
import '../../../shared/m3u/m3u_save_picker.dart';
import '../../../shared/play_tracks.dart';
import '../../../shared/track_menu_actions.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/context_modal/context_modal_nav.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../history_routes.dart';
import 'history_clear_dialog.dart';
import 'history_page_modal_data.dart';

final _log = Logger('history');

Future<List<Track>> _readPlayed(LibraryDatabase db, String? covers) async => [
  for (final t in await db.historyPlayedTracks()) trackFromRow(t, covers),
];

/// What one open History modal holds: everything its actions need from the
/// widget tree, captured before it opened, so the page may be left while the
/// modal is open. The played songs are read when a row is tapped, never kept.
class HistoryPageModalSession {
  HistoryPageModalSession({
    required this.runner,
    required this.covers,
    required this.now,
    this.recorder,
  });

  final TrackMenuRunner runner;
  final String? covers;

  /// The page's clock; the Clear dialog reads it once, when it opens.
  final DateTime Function() now;

  /// Runs the Clear delete; `null` without a library.
  final ListenRecorder? recorder;

  /// True while the Clear dialog is open above the modal: a second tap
  /// meanwhile must not stack another one.
  bool _dialogOpen = false;

  /// Whether a clear (from here or Settings) is queued or running.
  ValueListenable<bool> get clearing => recorder?.clearing ?? _idle;
  static final _idle = ValueNotifier<bool>(false);

  /// Names the songs in snackbars, the picker and the export file.
  String get label => runner.l10n.navHistory;

  /// Every played song still in the library, last played first.
  Future<List<Track>> _read() {
    final db = runner.db;
    if (db == null) throw StateError('No library is open');
    return _readPlayed(db, covers);
  }

  /// The songs, or null after saying why there is nothing to act on: none is
  /// in the library, or the read failed.
  Future<List<Track>?> _readOrSay() async {
    final messenger = runner.messenger;
    final l10n = runner.l10n;
    try {
      final tracks = await _read();
      if (tracks.isNotEmpty) return tracks;
      messenger?.showAppSnackBar(
        AppSnackBarKind.info,
        l10n.historyNothingInLibrary,
      );
    } on Object catch (error, stack) {
      _log.severe('Reading the played songs failed', error, stack);
      messenger?.showAppSnackBar(
        AppSnackBarKind.error,
        l10n.libraryUnexpectedError,
      );
    }
    return null;
  }

  /// Runs a queue action of the footer on the played songs.
  void queue(QueueAction action) =>
      runner.queueHost?.enqueueFromDatabase(action, label, _readPlayed);

  /// Replaces the queue with the played songs, last played first; [shuffle]
  /// turns shuffle on and starts from a random one.
  Future<void> play({bool shuffle = false}) async {
    final tracks = await _readOrSay();
    if (tracks == null) return;
    final player = runner.container.read(playerServiceProvider.notifier);
    await (shuffle ? player.openShuffled(tracks) : player.openTracks(tracks));
  }

  Future<void> addToPlaylist() async {
    final host = runner.queueHost;
    if (host == null) return;
    // Read first: with no song in the library no picker opens.
    final tracks = await _readOrSay();
    if (tracks == null) return;
    host.enqueueLoaded(
      QueueAction.addToPlaylist,
      tracks,
      label,
      suggestedName: label,
    );
  }

  Future<void> export(M3uPathStyle style) async {
    final messenger = runner.messenger;
    if (messenger == null) return;
    // Read first: with no song in the library no picker opens.
    final tracks = await _readOrSay();
    if (tracks == null) return;
    await exportM3uWith(
      save: runner.container.read(m3uSavePickerProvider),
      messenger: messenger,
      l10n: runner.l10n,
      navigator: runner.rootNavigator,
      name: label,
      style: style,
      readEntries: () async => [
        for (final t in tracks)
          M3uExportEntry(
            path: t.uri,
            title: t.title,
            artist: t.artist,
            durationMs: t.duration?.inMilliseconds,
          ),
      ],
    );
  }

  /// Asks which part to clear above the modal (Cancel comes back to it),
  /// closes the modal, clears, and says how many listens went. [plays] is
  /// the size of the whole history, for the Everything option.
  Future<void> clear(ContextModalNav nav, int plays) async {
    final navigator = runner.rootNavigator;
    final db = runner.db;
    final clearer = recorder;
    if (clearer == null ||
        db == null ||
        navigator == null ||
        !navigator.mounted ||
        _dialogOpen ||
        clearer.clearing.value) {
      return;
    }
    _dialogOpen = true;
    final ClearBounds? bounds;
    try {
      bounds = await showHistoryClearDialog(
        navigator.context,
        db: db,
        now: now(),
        everythingPlays: plays,
      );
    } finally {
      _dialogOpen = false;
    }
    if (bounds == null) return;
    nav.close();
    final removed = await clearer.clearHistory(
      from: bounds.from,
      to: bounds.to,
    );
    final messenger = runner.messenger;
    if (messenger == null || !messenger.mounted) return;
    final l10n = runner.l10n;
    messenger.showAppSnackBar(
      removed == null ? AppSnackBarKind.error : AppSnackBarKind.success,
      removed == null
          ? l10n.listenHistoryClearFailed
          : l10n.historyCleared(removed),
    );
  }

  /// The callbacks the rows call. [plays] is the number of listens now.
  HistoryPageModalHandlers handlers({int plays = 0}) =>
      HistoryPageModalHandlers(
        clear: recorder == null ? null : (nav) => unawaited(clear(nav, plays)),
        play: () => unawaited(play()),
        shuffle: () => unawaited(play(shuffle: true)),
        addToPlaylist: () => unawaited(addToPlaylist()),
        openMostPlayed: () => runner.goTo(mostPlayedPath),
        exportAbsolute: () => unawaited(export(M3uPathStyle.absolute)),
        exportRelative: () => unawaited(export(M3uPathStyle.relative)),
      );
}
