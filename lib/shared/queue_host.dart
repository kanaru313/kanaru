import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/database/library_database.dart' show LibraryDatabase;
import '../core/database/library_startup.dart' show coverCacheDirectoryProvider;
import '../core/player/playing_track_art.dart' show localPathOf;
import '../core/player/track.dart';
import '../l10n/l10n.dart';
import 'enqueue_chain.dart';
import 'widgets/add_to_playlist/add_to_playlist_flow.dart';
import 'widgets/queue_actions_menu.dart';

final _hostKey = Object();
final _viaKeyboardKey = Object();

/// What a queue action needs from the widget tree (provider container,
/// messenger, texts, root navigator, library), captured while the row that
/// asked is still on screen. The song modal runs its queue actions after it
/// has closed, when that row can already be gone; [enqueueLoaded] then uses
/// the host instead of the row's own `WidgetRef` and `BuildContext`, which
/// are no longer valid. [enqueueLoaded] and `enqueueFromDatabase` honor a host.
///
/// A caller that itself checks `mounted` before acting (the songs list) still
/// drops the action when its whole screen is gone; that is accepted.
class QueueHost {
  /// Built by `TrackMenuRunner` from the fields it captured before the modal
  /// opened; the host only wraps them, nothing is captured a second time.
  QueueHost.captured({
    required this._container,
    required this._messenger,
    required this._l10n,
    required this._dialogContext,
    required this._db,
  });

  final ProviderContainer _container;
  final ScaffoldMessengerState _messenger;
  final AppLocalizations _l10n;

  /// The root navigator's context, which outlives the page.
  final BuildContext _dialogContext;
  final LibraryDatabase? _db;

  /// The host of the queue action running right now, if any.
  static QueueHost? get current => Zone.current[_hostKey] as QueueHost?;

  /// True when the current zone runs an action initiated via keyboard.
  static bool get currentViaKeyboard =>
      Zone.current[_viaKeyboardKey] as bool? ?? false;

  /// Runs [action] with [viaKeyboard] in effect.
  static void runWithViaKeyboard(bool viaKeyboard, void Function() action) {
    if (!viaKeyboard) return action();
    runZoned(action, zoneValues: {_viaKeyboardKey: true});
  }

  /// Runs [action] so that [enqueueLoaded] and `enqueueFromDatabase` calls made inside it, sync or
  /// async (work started in its zone), use [host]. A null [host] runs
  /// [action] unchanged.
  static void run(
    QueueHost? host,
    void Function() action, {
    bool? viaKeyboard,
  }) {
    final keyboard = viaKeyboard ?? currentViaKeyboard;
    if (host == null && !keyboard) return action();
    runZoned(
      action,
      zoneValues: {
        _hostKey: ?host,
        if (keyboard) _viaKeyboardKey: true,
      },
    );
  }

  /// Copies the local file paths [readPaths] returns (it gets the open
  /// library) into a playlist the user picks, and says how many went in,
  /// naming [label]. [excludePlaylistId] hides a playlist in the picker;
  /// [suggestedName] prefills the first new playlist. Does nothing when no
  /// library is open.
  void addToPlaylist(
    Future<List<String>> Function(LibraryDatabase db) readPaths,
    String label, {
    int? excludePlaylistId,
    String? suggestedName,
    bool? viaKeyboard,
  }) {
    final db = _db;
    if (db == null) return;
    unawaited(
      addTracksToPlaylistWith(
        db: db,
        messenger: _messenger,
        l10n: _l10n,
        dialogContext: _dialogContext,
        readPaths: () => readPaths(db),
        label: label,
        excludePlaylistId: excludePlaylistId,
        suggestedName: suggestedName,
        viaKeyboard: viaKeyboard ?? currentViaKeyboard,
      ),
    );
  }

  /// `enqueueFromDatabase` without the row's `WidgetRef` and `BuildContext`:
  /// [read] gets the open library and the cover cache directory. Does nothing
  /// when no library is open.
  void enqueueFromDatabase(
    QueueAction action,
    String label,
    Future<List<Track>> Function(LibraryDatabase db, String? covers) read, {
    String? suggestedName,
  }) {
    final db = _db;
    if (db == null) return;
    final covers = _container.read(coverCacheDirectoryProvider);
    if (action == QueueAction.addToPlaylist) {
      addToPlaylist(
        (db) async => [
          for (final t in await read(db, covers)) ?localPathOf(t.uri),
        ],
        label,
        suggestedName: suggestedName,
      );
      return;
    }
    unawaited(
      enqueueTracksIn(
        _container,
        _messenger,
        _l10n,
        action,
        () => read(db, covers),
        label,
      ),
    );
  }

  /// [enqueueLoaded] without the row's `WidgetRef` and `BuildContext`.
  /// [excludePlaylistId] hides the playlist the tracks come from in the
  /// "Add to playlist" picker; [suggestedName] prefills the first new one.
  void enqueueLoaded(
    QueueAction action,
    List<Track> tracks,
    String label, {
    int? excludePlaylistId,
    String? suggestedName,
  }) {
    if (action == QueueAction.addToPlaylist) {
      addToPlaylist(
        // Library tracks carry their file path as uri.
        (_) async => [for (final t in tracks) ?localPathOf(t.uri)],
        label,
        excludePlaylistId: excludePlaylistId,
        suggestedName: suggestedName,
      );
      return;
    }
    unawaited(
      enqueueTracksIn(
        _container,
        _messenger,
        _l10n,
        action,
        () async => tracks,
        label,
      ),
    );
  }
}
