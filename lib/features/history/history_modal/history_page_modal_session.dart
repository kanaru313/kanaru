import 'dart:async';

import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/history_queries.dart';
import '../../../core/database/library_database.dart' show LibraryDatabase;
import '../../../core/m3u/m3u_write.dart' show M3uExportEntry, M3uPathStyle;
import '../../../core/player/track.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/m3u/m3u_export_flow.dart';
import '../../../shared/m3u/m3u_save_picker.dart';
import '../../../shared/play_tracks.dart';
import '../../../shared/track_menu_actions.dart';
import '../../../shared/widgets/add_to_playlist/add_to_playlist_flow.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/context_modal/context_modal_nav.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../history_routes.dart';
import 'history_page_modal_actions.dart';

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
    required this.db,
    required this.covers,
    required this.l10n,
    required this.messenger,
    required this.rootNavigator,
    required this.save,
  });

  final TrackMenuRunner runner;
  final LibraryDatabase db;
  final String? covers;
  final AppLocalizations l10n;
  final ScaffoldMessengerState messenger;
  final NavigatorState? rootNavigator;
  final M3uSavePicker save;

  /// Names the songs in snackbars, the picker and the export file.
  String get label => l10n.navHistory;

  /// Every played song still in the library, last played first.
  Future<List<Track>> _read() => _readPlayed(db, covers);

  /// The songs, or null after saying why there is nothing to act on: none is
  /// in the library, or the read failed.
  Future<List<Track>?> _readOrSay() async {
    try {
      final tracks = await _read();
      if (tracks.isNotEmpty) return tracks;
      messenger.showAppSnackBar(
        AppSnackBarKind.info,
        l10n.historyNothingInLibrary,
      );
    } on Object catch (error, stack) {
      _log.severe('Reading the played songs failed', error, stack);
      messenger.showAppSnackBar(
        AppSnackBarKind.error,
        l10n.libraryUnexpectedError,
      );
    }
    return null;
  }

  /// Runs a queue action of the footer on the played songs.
  void queue(QueueAction action) =>
      runner.queueHost?.enqueueFromDatabase(action, label, _readPlayed);

  Future<void> addToPlaylist() async {
    final navigator = rootNavigator;
    if (navigator == null || !navigator.mounted) return;
    final tracks = await _readOrSay();
    if (tracks == null || !navigator.mounted) return;
    await addTracksToPlaylistWith(
      db: db,
      messenger: messenger,
      l10n: l10n,
      dialogContext: navigator.context,
      // Library songs carry their file path as uri.
      readPaths: () async => [for (final t in tracks) t.uri],
      label: label,
      suggestedName: label,
    );
  }

  Future<void> export(M3uPathStyle style) async {
    // Read first: with no song in the library no picker opens.
    final tracks = await _readOrSay();
    if (tracks == null) return;
    await exportM3uWith(
      save: save,
      messenger: messenger,
      l10n: l10n,
      navigator: rootNavigator,
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

  /// The callbacks the rows call.
  HistoryPageModalHandlers handlers({
    void Function(ContextModalNav nav)? openAdvanced,
  }) => HistoryPageModalHandlers(
    openAdvanced: openAdvanced,
    addToPlaylist: () => unawaited(addToPlaylist()),
    openMostPlayed: () => runner.goTo(mostPlayedPath),
    exportAbsolute: () => unawaited(export(M3uPathStyle.absolute)),
    exportRelative: () => unawaited(export(M3uPathStyle.relative)),
  );
}
