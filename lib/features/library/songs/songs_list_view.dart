import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart' show TrackListItem;
import '../../../core/database/library_song_paging.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/indexer/cover_paths.dart';
import '../../../core/indexer/indexer_providers.dart';
import '../../../core/indexer/indexer_state.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../l10n/l10n.dart';
import '../albums/album_grid_tile.dart' show albumGridPadding;
import '../library_browse_body.dart';
import '../library_view_modes.dart';
import '../../../shared/enqueue_tracks.dart';
import '../../../shared/play_tracks.dart';
import '../../../shared/widgets/library_loading.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../../../shared/widgets/song_tile.dart';
import 'song_grid_tile.dart';
import 'songs_empty_view.dart';
import 'songs_list_provider.dart';
import 'songs_windowed_list.dart';

final _log = Logger('library');

/// The stored songs as a list or a grid. Shows a progress indicator until the first
/// result, the "unavailable" message when reading failed, and the "no songs"
/// message for an empty library unless a scan is still [scanning] or the
/// list is reloading. Tapping a
/// song plays the whole list from it.
///
/// Changing the sort keeps the current rows until the re-sorted list
/// arrives, then scrolls back to the top.
class SongsListView extends ConsumerStatefulWidget {
  const SongsListView({super.key, required this.scanning});

  final bool scanning;

  @override
  ConsumerState<SongsListView> createState() => _SongsListViewState();
}

class _SongsListViewState extends ConsumerState<SongsListView> {
  final _scroll = ScrollController();

  /// The sort changed and the list has not been re-sorted yet.
  bool _resorting = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Plays the list in the sort [songs] was read in, from the track with
  /// [trackId]. The queue and the start come from one read, so the start is
  /// the position of that track in that queue even if a scan changed the
  /// library meanwhile; when the track is gone nothing plays.
  Future<void> _play(SongIds songs, int trackId) async {
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    final covers = ref.read(coverCacheDirectoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final (items, start) = await db.songQueueFrom(
        trackId,
        order: songs.order,
        descending: songs.descending,
      );
      if (!mounted) return;
      if (start == null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.songsTrackGone)));
        return;
      }
      playTracks(ref, [
        for (final s in items)
          trackFromItem(
            path: s.path,
            title: s.title,
            artist: s.artist,
            durationMs: s.durationMs,
            artPath: coverPath(covers, s.coverKey),
          ),
      ], start);
    } catch (error, stackTrace) {
      _log.severe('Reading the play queue failed', error, stackTrace);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.libraryUnexpectedError)),
        );
      }
    }
  }

  /// Queues one song of the list from its menu.
  void _enqueue(TrackListItem song, QueueAction action) {
    // The menu closes later than it opened: the list may be gone by then.
    if (!mounted) return;
    final track = trackFromItem(
      path: song.path,
      title: song.title,
      artist: song.artist,
      durationMs: song.durationMs,
      artPath: coverPath(ref.read(coverCacheDirectoryProvider), song.coverKey),
    );
    enqueueLoaded(ref, context, action, [track], song.title);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider.select((s) => s.songSort), (_, _) {
      _resorting = true;
    });
    // A scan that ends while the list is empty (a short first scan) would
    // otherwise wait out the refresh interval before its songs show.
    ref.listen(libraryIndexerProvider.select((s) => s is IndexerScanning), (
      wasScanning,
      scanning,
    ) {
      if (wasScanning == true &&
          !scanning &&
          (ref.read(songIdsProvider).value?.ids.isEmpty ?? false)) {
        ref.invalidate(songIdsProvider);
      }
    });
    ref.listen(songIdsProvider, (previous, next) {
      if (next.hasError && !(previous?.hasError ?? false)) {
        _log.severe('Reading the songs failed', next.error, next.stackTrace);
      }
      if (_resorting && next.hasValue && !next.isLoading) {
        _resorting = false;
        if (_scroll.hasClients) _scroll.jumpTo(0);
      }
    });

    final grid = ref.watch(
      libraryViewModesProvider.select((m) => m.songs == AlbumsView.grid),
    );
    final async = ref.watch(songIdsProvider);
    return async.when(
      skipLoadingOnReload: true,
      loading: () => _firstRows(grid: grid),
      error: (error, stackTrace) =>
          const SongsEmptyView(kind: SongsEmptyKind.unavailable),
      data: (songs) {
        if (songs.ids.isEmpty) {
          // Still reloading after a scan: rows may be about to arrive.
          return widget.scanning || async.isLoading
              ? const SizedBox.shrink()
              : const SongsEmptyView(kind: SongsEmptyKind.noTracks);
        }
        return SongsWindowedList(
          songs: songs,
          controller: _scroll,
          seed: ref.read(songsFirstPageProvider).value ?? const [],
          onTap: (id) => _play(songs, id),
          onQueueAction: _enqueue,
          grid: grid,
        );
      },
    );
  }

  /// While the ids of a large library are read: its first page, so rows show
  /// at once. Tapping one plays in the saved sort.
  Widget _firstRows({required bool grid}) {
    final rows = ref.watch(songsFirstPageProvider).value;
    if (rows == null || rows.isEmpty) return const LibraryLoading();
    final sort = ref.read(settingsProvider).songSort;
    final songs = SongIds(const [], songOrderFor(sort.field), sort.descending);
    if (grid) {
      return LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            albumGridPadding,
            0,
            albumGridPadding,
            libraryBottomInset,
          ),
          gridDelegate: songGridDelegate(
            context,
            constraints.maxWidth - albumGridPadding * 2,
          ),
          itemCount: rows.length,
          itemBuilder: (context, i) => SongGridTile(
            song: rows[i],
            onTap: () => _play(songs, rows[i].id),
            onQueueAction: (action) => _enqueue(rows[i], action),
          ),
        ),
      );
    }
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: libraryListBottomPadding,
      prototypeItem: SongTile(song: prototypeSong, onTap: () {}),
      itemCount: rows.length,
      itemBuilder: (context, i) => SongTile(
        song: rows[i],
        onTap: () => _play(songs, rows[i].id),
        onQueueAction: (action) => _enqueue(rows[i], action),
      ),
    );
  }
}
