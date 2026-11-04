import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/playlist_favorites.dart';
import '../../../core/database/playlist_queries.dart';
import '../../../l10n/l10n.dart';
import 'add_to_playlist_dialog.dart';
import 'add_to_playlist_messages.dart';
import '../app_snack_bar.dart';

final _log = Logger('playlists');

/// Asks which playlists (several, or new ones), reads [readPaths], adds the
/// songs in one transaction and says how many went where, naming [label].
/// [excludePlaylistId] hides the playlist the songs come from. Nothing asks
/// about duplicates yet: playlists already holding some get the missing songs
/// only.
///
/// Everything from the widget tree is captured before the first `await`:
/// the row that opened the menu can be rebuilt away by a rescan while the
/// picker is open. Failures are logged and reported in a snackbar, never
/// thrown to the caller.
Future<void> addTracksToPlaylist(
  WidgetRef ref,
  BuildContext context,
  Future<List<String>> Function() readPaths,
  String label, {
  int? excludePlaylistId,
  bool viaKeyboard = false,
}) async {
  if (!context.mounted) return;
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  await addTracksToPlaylistWith(
    db: db,
    messenger: ScaffoldMessenger.of(context),
    l10n: context.l10n,
    // The root navigator outlives the page, and sits above Now Playing.
    dialogContext: Navigator.of(context, rootNavigator: true).context,
    readPaths: readPaths,
    label: label,
    excludePlaylistId: excludePlaylistId,
    viaKeyboard: viaKeyboard,
  );
}

/// [addTracksToPlaylist] with everything it needs from the widget tree
/// already captured, for a caller whose row may be gone by the time the
/// picker answers (the queue menu). [dialogContext] is the root navigator's
/// context. [suggestedName] prefills the name of the first "New playlist"
/// (null keeps the default name).
Future<void> addTracksToPlaylistWith({
  required LibraryDatabase db,
  required ScaffoldMessengerState? messenger,
  required AppLocalizations l10n,
  required BuildContext dialogContext,
  required Future<List<String>> Function() readPaths,
  required String label,
  int? excludePlaylistId,
  String? suggestedName,
  bool viaKeyboard = false,
}) async {
  if (!dialogContext.mounted) return;
  // Read while the picker is open, for its hints. A failure surfaces when
  // Add awaits the future, so it is handled here only to keep it unreported.
  final paths = Future<List<String>>.sync(readPaths);
  unawaited(paths.then((_) {}, onError: (_, _) {}));

  AppSnackBarKind kind;
  String text;
  try {
    final plan = await showPlaylistPicker(
      dialogContext,
      db: db,
      paths: paths,
      label: label,
      excludePlaylistId: excludePlaylistId,
      suggestedName: suggestedName,
      viaKeyboard: viaKeyboard,
    );
    // Dismissed, or the album or artist vanished in a rescan: nothing to add.
    if (plan == null) return;
    final outcome = await db.addToPlaylists(
      paths: plan.paths,
      targets: {for (final e in plan.targets.entries) e.key.id: e.value},
      newNames: plan.newNames,
      now: DateTime.now().millisecondsSinceEpoch,
    );
    // Which targets were gone is only known by looking again.
    final existing = outcome.gone == 0
        ? null
        : {for (final p in await db.watchPlaylistSummaries().first) p.id};
    (kind, text) = playlistAddMessage(
      l10n,
      outcome,
      plan,
      label,
      existingIds: existing,
    );
  } catch (error, stack) {
    _log.severe('Adding to a playlist failed', error, stack);
    kind = AppSnackBarKind.error;
    text = l10n.playlistSaveFailed;
  }
  _showPlaylistMessage(messenger, kind, text);
}

/// Adds the songs [readPaths] returns to the Favorites playlist (created when
/// missing) in one transaction, skipping those already there, and says how
/// many went in, naming [label]. Nothing is shown for an empty list. Failures
/// are logged and reported in a snackbar, never thrown.
Future<void> addTracksToFavoritesWith({
  required LibraryDatabase db,
  required ScaffoldMessengerState? messenger,
  required AppLocalizations l10n,
  required Future<List<String>> Function() readPaths,
  required String label,
}) async {
  String text;
  AppSnackBarKind kind;
  try {
    final paths = await readPaths();
    if (paths.isEmpty) return;
    final (:added, :skipped) = await db.transaction(() async {
      final id = await db.ensureFavoritesPlaylist(
        now: DateTime.now().millisecondsSinceEpoch,
      );
      return db.addMissingToPlaylist(id, paths);
    });
    kind = playlistAddedKind(added);
    text = playlistAddedText(l10n, label, l10n.navFavorites, added, skipped);
  } catch (error, stack) {
    _log.severe('Adding to Favorites failed', error, stack);
    kind = AppSnackBarKind.error;
    text = l10n.playlistSaveFailed;
  }
  _showPlaylistMessage(messenger, kind, text);
}

/// Shows [text] in [messenger]. The songs are saved: failing to say so is no
/// saving failure. An older message (a queue pick, an earlier add) gives way
/// instead of holding this one back.
void _showPlaylistMessage(
  ScaffoldMessengerState? messenger,
  AppSnackBarKind kind,
  String text,
) {
  try {
    messenger?.showAppSnackBar(kind, text);
  } catch (error, stack) {
    _log.warning('Showing the playlist message failed', error, stack);
  }
}
