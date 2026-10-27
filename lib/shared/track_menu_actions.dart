import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../core/database/library_browse_track_links.dart';
import '../core/database/library_database.dart';
import '../core/database/library_startup.dart';
import '../core/database/playlist_favorites.dart';
import '../core/database/playlist_library_paths.dart';
import '../l10n/l10n.dart';
import 'icons/app_icons.dart';
import 'library_route_keys.dart';
import 'show_in_file_manager.dart';
import 'track_menu_choice.dart';
import 'widgets/queue_actions_menu.dart';
import 'widgets/app_snack_bar.dart';

final _log = Logger('track_menu');

/// Carries out the song menu: opens a song's artist, album or folder page,
/// shows its file in the file manager, or puts it in or out of Favorites.
///
/// Built before the menu opens, because what it needs from the widget tree
/// (router, messenger, texts) must outlive the row: a rescan can rebuild the
/// row away while the menu is open. Without a router or messenger above the
/// row (a menu in an isolated widget), the artist, album and folder links do
/// nothing. Their keys are read when an item is picked, not when the row is
/// built.
/// Failures are logged and reported in a snackbar, never thrown.
class TrackMenuRunner {
  TrackMenuRunner(WidgetRef ref, this._context)
    : _router = GoRouter.maybeOf(_context),
      _messenger = ScaffoldMessenger.maybeOf(_context),
      _l10n = _context.l10n,
      _db = ref.read(libraryDatabaseProvider),
      _showInFileManager = ref.read(showInFileManagerProvider);

  final BuildContext _context;
  final GoRouter? _router;
  final ScaffoldMessengerState? _messenger;
  final AppLocalizations _l10n;
  final LibraryDatabase? _db;
  final Future<bool> Function(String path) _showInFileManager;

  void _say(AppSnackBarKind kind, String text) => _messenger
    ?..clearSnackBars()
    ..showSnackBar(appSnackBar(kind: kind, title: text));

  /// Follows [choice] for the song [trackId] stored at [path]. A song
  /// credited to several artists asks which one at [position] (global).
  /// Queue choices belong to the caller and are ignored.
  Future<void> run(
    TrackMenuChoice choice, {
    required int trackId,
    required String path,
    required Offset position,
  }) async {
    try {
      switch (choice) {
        case QueueChoice():
          return;
        case FavoriteChoice(:final favorite):
          final db = _db;
          if (db == null) {
            _say(AppSnackBarKind.error, _l10n.libraryUnexpectedError);
            return;
          }
          // [path] is the song's `tracks.path`: a library row, so it may be
          // liked without a check.
          await db.setFavorite(
            path,
            favorite: favorite,
            now: DateTime.now().millisecondsSinceEpoch,
          );
          _say(
            AppSnackBarKind.success,
            favorite ? _l10n.favoritesAdded : _l10n.favoritesRemoved,
          );
        case ShowInFileManagerChoice():
          if (!await _showInFileManager(path)) {
            _say(AppSnackBarKind.error, _l10n.libraryFileManagerFailed);
          }
        case ShowFolderChoice():
          final router = _router;
          if (router == null) return;
          final db = _db;
          if (db == null) {
            _say(AppSnackBarKind.error, _l10n.libraryUnexpectedError);
            return;
          }
          // A stale row (rescan) may no longer be in the library.
          if (!(await db.libraryPathsAmong([path])).contains(path)) {
            _say(AppSnackBarKind.warning, _l10n.libraryTrackGone);
            return;
          }
          // The tree's folder key for a path below a root.
          router.go(folderLocation(path.substring(0, path.lastIndexOf('/'))));
        case ShowArtistChoice() || ShowAlbumChoice():
          final router = _router;
          if (router == null) return;
          final db = _db;
          if (db == null) {
            _say(AppSnackBarKind.error, _l10n.libraryUnexpectedError);
            return;
          }
          final links = await db.trackLinks(trackId);
          if (links == null) {
            _say(AppSnackBarKind.warning, _l10n.libraryTrackGone);
            return;
          }
          if (choice is ShowAlbumChoice) {
            final album = links.album;
            if (album == null) {
              _say(AppSnackBarKind.info, _l10n.libraryNoAlbumToShow);
            } else {
              router.go(albumLocation(album));
            }
          } else {
            await _showArtist(router, links.artists, position);
          }
      }
    } catch (error, stack) {
      _log.severe('A song menu action failed', error, stack);
      _say(AppSnackBarKind.error, _l10n.libraryUnexpectedError);
    }
  }

  Future<void> _showArtist(
    GoRouter router,
    List<({String key, String name})> artists,
    Offset position,
  ) async {
    if (artists.isEmpty) {
      _say(AppSnackBarKind.info, _l10n.libraryNoArtistToShow);
      return;
    }
    if (artists.length == 1) {
      router.go(artistLocation(artists.single.key));
      return;
    }
    // The row is gone (a rescan): there is nowhere to anchor the picker.
    if (!_context.mounted) return;
    final key = await showArtistPicker(_context, position, artists);
    if (key != null) router.go(artistLocation(key));
  }
}

/// Opens a second menu at [position] (global) naming the artists of a song
/// credited to several; returns the chosen artist key, or null when it was
/// dismissed.
Future<String?> showArtistPicker(
  BuildContext context,
  Offset position,
  List<({String key, String name})> artists,
) => showMenu<String>(
  context: context,
  position: menuPositionAt(context, position),
  semanticLabel: context.l10n.libraryChooseArtist,
  items: [
    for (final artist in artists)
      menuRow(artist.key, AppIcons.artistOutline, artist.name),
  ],
);
