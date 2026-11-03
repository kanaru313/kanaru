import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../core/database/history_rows.dart';
import '../../../core/database/library_database.dart' show LibraryDatabase;
import '../../../core/database/playlist_cover_keys.dart';
import '../../../core/m3u/m3u_write.dart' show M3uExportEntry, M3uPathStyle;
import '../../../core/player/player_service.dart';
import '../../../core/player/track.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/m3u/m3u_export_flow.dart';
import '../../../shared/m3u/m3u_save_picker.dart';
import '../../../shared/track_menu_actions.dart';
import '../../../shared/widgets/add_to_playlist/add_to_playlist_flow.dart';
import '../../../shared/widgets/queue_actions_menu.dart';

import '../history_top_queue.dart';
import 'most_played_modal_actions.dart';

/// What one open Most played modal holds: the ranking on show when it opened,
/// cut to the songs still in the library (rank order), and everything its
/// actions need from the widget tree, captured before it opened. A reload of
/// the ranking while the modal is open never changes what the rows act on.
class MostPlayedModalSession {
  MostPlayedModalSession({
    required List<HistoryTopRow> rows,
    required String? covers,
    required this.rangeText,
    required this.totals,
    required this.runner,
    required this.db,
    required this.l10n,
    required this.messenger,
    required this.rootNavigator,
    required this.save,
  }) : tracks = historyTopPlayable(rows, covers),
       coverKeys = pickCollageKeys([
         for (final row in rows) row.track?.coverKey,
       ]);

  /// The library songs of the ranking, in rank order.
  final List<Track> tracks;

  /// The collage keys of the ranking, picked as the page picks them.
  final List<String> coverKeys;

  /// The range's text; names the playlist, the export and the snackbars.
  final String rangeText;

  /// The totals of the range, or null while they were not read.
  final HistoryRangeSummary? totals;

  final TrackMenuRunner runner;
  final LibraryDatabase db;
  final AppLocalizations l10n;
  final ScaffoldMessengerState messenger;
  final NavigatorState? rootNavigator;
  final M3uSavePicker save;

  /// Whether any listed song can be acted on.
  bool get canAct => tracks.isNotEmpty;

  /// The playlist name suggested for this range.
  String get playlistName => l10n.historyTopPlaylistName(rangeText);

  /// Library songs carry their file path as uri.
  List<String> get _paths => [for (final t in tracks) t.uri];

  void queue(QueueAction action) =>
      runner.queueHost?.enqueueLoaded(action, tracks, rangeText);

  /// Replaces the queue with the ranking's songs in rank order; [shuffle]
  /// turns shuffle on and starts from a random one.
  Future<void> play({bool shuffle = false}) async {
    final player = runner.container.read(playerServiceProvider.notifier);
    await (shuffle ? player.openShuffled(tracks) : player.openTracks(tracks));
  }

  Future<void> addToPlaylist() async {
    final navigator = rootNavigator;
    if (navigator == null || !navigator.mounted) return;
    await addTracksToPlaylistWith(
      db: db,
      messenger: messenger,
      l10n: l10n,
      dialogContext: navigator.context,
      readPaths: () async => _paths,
      label: rangeText,
      suggestedName: playlistName,
    );
  }

  Future<void> addToFavorites() =>
      runner.addPathsToFavorites((_) async => _paths, rangeText);

  Future<void> export(M3uPathStyle style) => exportM3uWith(
    save: save,
    messenger: messenger,
    l10n: l10n,
    navigator: rootNavigator,
    name: playlistName,
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

  /// The callbacks the rows call.
  MostPlayedModalHandlers handlers() => MostPlayedModalHandlers(
    play: () => unawaited(play()),
    shuffle: () => unawaited(play(shuffle: true)),
    addToPlaylist: () => unawaited(addToPlaylist()),
    addToFavorites: () => unawaited(addToFavorites()),
    exportAbsolute: () => unawaited(export(M3uPathStyle.absolute)),
    exportRelative: () => unawaited(export(M3uPathStyle.relative)),
  );
}
