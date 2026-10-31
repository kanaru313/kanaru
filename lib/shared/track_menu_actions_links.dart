part of 'track_menu_actions.dart';

/// What the song modal needs beyond [TrackMenuRunner.run]: the queue host
/// and the artist links.
extension TrackMenuRunnerLinks on TrackMenuRunner {
  /// What queue actions need from the tree, for the song modal to run them
  /// after the row is gone; null without a messenger or root navigator.
  QueueHost? get queueHost {
    final messenger = _messenger;
    final navigator = _navigator;
    if (messenger == null || navigator == null) return null;
    return QueueHost.captured(
      container: _container,
      messenger: messenger,
      l10n: _l10n,
      dialogContext: navigator.context,
      db: _db,
    );
  }

  /// Opens the page of the artist [key] of the song [trackId], as the modal's
  /// artist rows and chips do. A song gone from the library says so. Does
  /// nothing without a router above the row.
  Future<void> openArtist(String key, {required int trackId}) async {
    try {
      final router = _router;
      if (router == null) return;
      final db = _db;
      if (db == null) {
        _say(AppSnackBarKind.error, _l10n.libraryUnexpectedError);
        return;
      }
      if (await db.trackLinks(trackId) == null) {
        _say(AppSnackBarKind.warning, _l10n.libraryTrackGone);
        return;
      }
      router.go(artistLocation(key));
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
