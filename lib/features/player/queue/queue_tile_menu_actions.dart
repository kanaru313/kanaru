import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/database/playlist_favorites.dart';
import '../../../core/database/playlist_library_paths.dart';
import '../../../core/lyrics/online/lyrics_target.dart';
import '../../../core/player/play_queue.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/track.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/track_menu_actions.dart';
import '../../../shared/track_menu_choice.dart';
import '../../../shared/widgets/add_to_playlist/add_to_playlist_flow.dart';
import '../../../shared/widgets/queue_actions_menu.dart';

final _log = Logger('queue');

/// The rows of the queue menu that are the queue's own; the links and the
/// file manager row are [TrackMenuChoice]s.
enum QueueRowChoice { playNext, addToPlaylist, like, unlike, remove }

/// What the menu of one queue row was opened for, captured before it opens:
/// the row may be rebuilt away (the sheet closes, a rescan) before an item
/// is picked, so nothing here reads the row's context or ref afterwards.
class QueueRowMenuTarget {
  QueueRowMenuTarget({
    required this.container,
    required this.entry,
    required this.track,
    required this.path,
    required this.trackId,
    required this.runner,
    required this.messenger,
    required this.l10n,
    required this.navigator,
    required this.position,
  });

  final ProviderContainer container;

  /// The queue entry of the row ([PlayQueue.original] index).
  final int entry;

  /// The track at that entry when the menu opened.
  final Track track;

  /// The local file of the track; null for a stream.
  final String? path;

  /// The library id of the track; null outside the library.
  final int? trackId;
  final TrackMenuRunner runner;
  final ScaffoldMessengerState? messenger;
  final AppLocalizations l10n;

  /// The root navigator, which outlives the row; its context hosts the
  /// playlist picker.
  final NavigatorState navigator;

  /// Global point the menu opened at, where an artist picker would go.
  final Offset position;

  void _say(AppSnackBarKind kind, String text) => messenger
    ?..clearSnackBars()
    ..showSnackBar(appSnackBar(kind: kind, title: text));

  /// The play position of the entry, or null when the queue no longer holds
  /// this very track at it. Entry numbers are reused after the queue is
  /// cleared or replaced, so a number alone could name another song.
  int? _livePosition() {
    final queue = container.read(playerServiceProvider).queue;
    if (entry >= queue.original.length) return null;
    if (!identical(queue.original[entry], track)) return null;
    final at = queue.order.indexOf(entry);
    return at < 0 ? null : at;
  }

  /// Carries out the picked [choice]. Never throws.
  Future<void> run(Object choice) async {
    final at = _livePosition();
    if (at == null) {
      _say(AppSnackBarKind.info, l10n.queueMenuStale);
      return;
    }
    try {
      switch (choice) {
        case QueueRowChoice.playNext:
          await container
              .read(playerServiceProvider.notifier)
              .moveToPlayNext(at);
        case QueueRowChoice.remove:
          await container.read(playerServiceProvider.notifier).removeTrack(at);
        case QueueRowChoice.like || QueueRowChoice.unlike:
          await _setFavorite(favorite: choice == QueueRowChoice.like);
        case QueueRowChoice.addToPlaylist:
          await _addToPlaylist();
        case TrackMenuChoice():
          final id = trackId;
          final file = path;
          if (file == null ||
              (id == null &&
                  choice is! ShowInFileManagerChoice &&
                  choice is! FindLyricsChoice)) {
            return;
          }
          await runner.run(
            choice,
            trackId: id ?? 0,
            path: file,
            position: position,
            lyricsTarget: LyricsTarget.fromTrack(track),
          );
      }
    } catch (error, stack) {
      _log.severe('A queue row menu action failed', error, stack);
      _say(AppSnackBarKind.error, l10n.libraryUnexpectedError);
    }
  }

  Future<void> _setFavorite({required bool favorite}) async {
    final db = container.read(libraryDatabaseProvider);
    final file = path;
    if (db == null || file == null) return;
    // Only a song of the library is added, as everywhere else; any song in
    // Favorites can be taken out. Checked now: a rescan may have dropped it.
    if (favorite && !(await db.libraryPathsAmong([file])).contains(file)) {
      _say(AppSnackBarKind.error, l10n.libraryTrackGone);
      return;
    }
    await db.setFavorite(
      file,
      favorite: favorite,
      now: DateTime.now().millisecondsSinceEpoch,
    );
    _say(
      AppSnackBarKind.success,
      favorite ? l10n.favoritesAdded : l10n.favoritesRemoved,
    );
  }

  Future<void> _addToPlaylist() async {
    final db = container.read(libraryDatabaseProvider);
    final file = path;
    if (db == null || file == null) return;
    await addTracksToPlaylistWith(
      db: db,
      messenger: messenger,
      l10n: l10n,
      dialogContext: navigator.context,
      readPaths: () async => [file],
      label: track.title,
    );
  }
}

/// A divider-free [entries] with dividers only between rows: none first,
/// last or doubled, so a menu with some groups left out stays tidy.
List<PopupMenuEntry<T>> tidyDividers<T>(List<PopupMenuEntry<T>> entries) {
  final out = <PopupMenuEntry<T>>[];
  for (final entry in entries) {
    if (entry is PopupMenuDivider) {
      if (out.isEmpty || out.last is PopupMenuDivider) continue;
    }
    out.add(entry);
  }
  while (out.isNotEmpty && out.last is PopupMenuDivider) {
    out.removeLast();
  }
  return out;
}

/// The own rows of the queue menu that go before the links.
List<PopupMenuEntry<Object>> queueRowLeadingItems(
  AppLocalizations l10n, {
  required bool playNext,
  required bool addToPlaylist,
  required bool? favorite,
  required bool inLibrary,
}) => [
  if (playNext)
    menuRow<Object>(
      QueueRowChoice.playNext,
      AppIcons.playlistPlay,
      l10n.queuePlayNext,
    ),
  if (addToPlaylist)
    menuRow<Object>(
      QueueRowChoice.addToPlaylist,
      AppIcons.addToPlaylist,
      l10n.playlistAddTo,
    ),
  if (favorite == true)
    menuRow<Object>(
      QueueRowChoice.unlike,
      AppIcons.favorite,
      l10n.favoritesRemove,
    )
  else if (favorite == false && inLibrary)
    menuRow<Object>(
      QueueRowChoice.like,
      AppIcons.favoriteOutline,
      l10n.nowPlayingFavorite,
    ),
];
