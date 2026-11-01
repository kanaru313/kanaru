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

  /// The provider container captured when the runner was made; it outlives
  /// the row.
  ProviderContainer get container => _container;

  /// Puts the local songs of album [key], in the order of its page, in
  /// Favorites and says how many went in, naming [title]. Uses only what the
  /// runner captured, so it works once the row is gone.
  Future<void> addAlbumToFavorites(AlbumKey key, String title) async {
    final db = _db;
    if (db == null) return;
    await addTracksToFavoritesWith(
      db: db,
      messenger: _messenger,
      l10n: _l10n,
      // Library tracks carry their file path as uri.
      readPaths: () async => [
        for (final t in await db.albumTracks(key)) ?localPathOf(t.path),
      ],
      label: title,
    );
  }

  /// Navigates to [location]. Does nothing without a router above the row.
  void goTo(String location) => _router?.go(location);

  /// Shows [path] in the file manager; says so when that fails.
  Future<void> showInFileManagerAt(String path) async {
    try {
      if (!await _showInFileManager(path)) {
        _say(AppSnackBarKind.error, _l10n.libraryFileManagerFailed);
      }
    } catch (error, stack) {
      _log.severe('A file manager action failed', error, stack);
      _say(AppSnackBarKind.error, _l10n.libraryFileManagerFailed);
    }
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
