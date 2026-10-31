import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/database/library_database.dart' show LibraryDatabase;
import '../core/player/playing_track_art.dart' show localPathOf;
import '../core/player/track.dart';
import '../l10n/l10n.dart';
import 'enqueue_chain.dart';
import 'widgets/add_to_playlist/add_to_playlist_flow.dart';
import 'widgets/queue_actions_menu.dart';

final _hostKey = Object();

/// What a queue action needs from the widget tree (provider container,
/// messenger, texts, root navigator, library), captured while the row that
/// asked is still on screen. The song modal runs its queue actions after it
/// has closed, when that row can already be gone; [enqueueLoaded] then uses
/// the host instead of the row's own `WidgetRef` and `BuildContext`, which
/// are no longer valid. Only [enqueueLoaded] honors a host.
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

  /// Runs [action] so that [enqueueLoaded] calls made inside it, sync or
  /// async (work started in its zone), use [host]. A null [host] runs
  /// [action] unchanged.
  static void run(QueueHost? host, void Function() action) {
    if (host == null) return action();
    runZoned(action, zoneValues: {_hostKey: host});
  }

  /// [enqueueLoaded] without the row's `WidgetRef` and `BuildContext`.
  void enqueueLoaded(QueueAction action, List<Track> tracks, String label) {
    if (action == QueueAction.addToPlaylist) {
      final db = _db;
      if (db == null) return;
      unawaited(
        addTracksToPlaylistWith(
          db: db,
          messenger: _messenger,
          l10n: _l10n,
          dialogContext: _dialogContext,
          // Library tracks carry their file path as uri.
          readPaths: () async => [for (final t in tracks) ?localPathOf(t.uri)],
          label: label,
        ),
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
