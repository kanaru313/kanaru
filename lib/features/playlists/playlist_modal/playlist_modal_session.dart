import 'dart:async';

import 'package:logging/logging.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart' show LibraryDatabase;
import '../../../core/database/playlist_rows.dart';
import '../../../core/m3u/m3u_write.dart' show M3uPathStyle;
import '../../../l10n/app_localizations.dart';
import '../../../shared/m3u/m3u_save_picker.dart';
import '../../../shared/track_menu_actions.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/context_modal/context_modal_nav.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../favorites_routes.dart';
import '../playlist_display_name.dart';
import '../playlist_play_actions.dart';
import '../playlist_routes.dart';
import 'playlist_modal_data.dart';
import 'playlist_modal_session_actions.dart';
import 'playlist_modal_session_writes.dart';

final _log = Logger('playlists');

/// What one open playlist modal holds: the playlist as it was when the modal
/// opened and everything its actions need from the widget tree, captured
/// before the modal opened. The row or page that opened it may be rebuilt
/// away meanwhile, so nothing here refers to its own `BuildContext`. Its
/// lifetime is one open modal; nothing is shared across modals.
class PlaylistModalSession {
  PlaylistModalSession({
    required this.playlist,
    required this.coverKeys,
    required this.runner,
    required this.db,
    required this.l10n,
    required this.openerMessenger,
    required this.rootNavigator,
    required this.router,
    required this.save,
    this.showGoTo = true,
    this.beforeRead,
  });

  /// The summary the modal was opened with. Handlers prefer the latest one.
  final PlaylistSummary playlist;
  final List<String> coverKeys;
  final TrackMenuRunner runner;
  final LibraryDatabase? db;
  final AppLocalizations l10n;

  /// The messenger of the page that opened the modal; the one that shows
  /// anything said after the modal has closed.
  final ScaffoldMessengerState? openerMessenger;
  final NavigatorState? rootNavigator;
  final GoRouter? router;
  final M3uSavePicker save;

  /// False on the page of the playlist itself.
  final bool showGoTo;

  /// Completes when the opener has no write in flight (a drag or a remove
  /// on the playlist page). Awaited before anything reads the entries.
  final Future<void> Function()? beforeRead;

  /// True while the Edit dialog or the Delete confirm is open above the
  /// modal: a second tap meanwhile must not stack another one.
  bool dialogOpen = false;

  /// Waits for [beforeRead]; a failure there is logged, never blocks the
  /// action.
  Future<void> ready() async {
    try {
      await beforeRead?.call();
    } catch (error, stack) {
      _log.warning('Waiting for the playlist writes failed', error, stack);
    }
  }

  /// Shows [text] in the opener's messenger; never throws.
  void say(AppSnackBarKind kind, String text) {
    try {
      openerMessenger?.showAppSnackBar(kind, text);
    } catch (error, stack) {
      _log.warning('Showing the playlist message failed', error, stack);
    }
  }

  /// Queue buttons of the footer for [latest].
  void queue(QueueAction action, PlaylistSummary latest) {
    runner.queueHost?.enqueueFromDatabase(
      action,
      playlistDisplayName(latest, l10n),
      (db, covers) async {
        await ready();
        return readPlaylistQueue(db, latest.id, covers);
      },
    );
  }

  /// The callbacks the actions call. [latest] and [latestCoverKeys] are the
  /// newest the page has (the loaded head, else the snapshot); the handlers
  /// use them for names and for Edit's initial values. [modalMessenger] is
  /// the modal's own, where Edit reports a failed save while it is open.
  PlaylistModalHandlers handlers({
    required PlaylistSummary latest,
    required List<String> latestCoverKeys,
    ScaffoldMessengerState? modalMessenger,
    void Function(ContextModalNav nav)? openAdvanced,
  }) {
    final id = latest.id;
    return PlaylistModalHandlers(
      openAdvanced: openAdvanced,
      goToPlaylist: () => runner.goTo(
        latest.isFavorites ? favoritesPath : playlistLocation(id),
      ),
      play: () => unawaited(play(id)),
      shuffle: () => unawaited(play(id, shuffle: true)),
      addToPlaylist: () => unawaited(addToPlaylist(latest)),
      edit: () => unawaited(edit(latest, latestCoverKeys, modalMessenger)),
      delete: (nav) => unawaited(delete(nav, latest)),
      addAllToFavorites: () => unawaited(addAllToFavorites(latest)),
      duplicate: () => unawaited(duplicate(latest)),
      exportAbsolute: () => unawaited(export(latest, M3uPathStyle.absolute)),
      exportRelative: () => unawaited(export(latest, M3uPathStyle.relative)),
      removeDuplicates: () => unawaited(removeRepeated(latest)),
      removeMissing: () => unawaited(removeMissing(latest)),
    );
  }
}
