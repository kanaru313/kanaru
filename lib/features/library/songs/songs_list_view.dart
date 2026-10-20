import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart' show TrackListItem;
import '../../../core/settings/settings_provider.dart';
import '../play_tracks.dart';
import '../widgets/library_loading.dart';
import 'song_tile.dart';
import 'songs_empty_view.dart';
import 'songs_list_provider.dart';

final _log = Logger('library');

/// Row used to measure the list: two lines and a duration, the tallest a
/// row gets, so rows without an artist are not squeezed.
const _prototypeSong = TrackListItem(
  id: 0,
  path: '',
  title: 'Title',
  artist: 'Artist',
  durationMs: 1000,
);

/// The stored songs as a list. Shows a progress indicator until the first
/// result, the "unavailable" message when reading failed, and the "no songs"
/// message for an empty library unless a scan is still [scanning]. Tapping a
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

  void _play(List<TrackListItem> songs, int index) {
    final tracks = [
      for (final s in songs)
        trackFromItem(
          path: s.path,
          title: s.title,
          artist: s.artist,
          durationMs: s.durationMs,
        ),
    ];
    playTracks(ref, tracks, index);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider.select((s) => s.songSort), (_, _) {
      _resorting = true;
    });
    ref.listen(songsListProvider, (previous, next) {
      if (next.hasError) {
        _log.severe('Reading the songs failed', next.error, next.stackTrace);
      }
      if (_resorting && next.hasValue && !next.isLoading) {
        _resorting = false;
        if (_scroll.hasClients) _scroll.jumpTo(0);
      }
    });

    return ref
        .watch(songsListProvider)
        .when(
          skipLoadingOnReload: true,
          loading: () => const LibraryLoading(),
          error: (error, stackTrace) =>
              const SongsEmptyView(kind: SongsEmptyKind.unavailable),
          data: (songs) {
            if (songs.isEmpty) {
              return widget.scanning
                  ? const SizedBox.shrink()
                  : const SongsEmptyView(kind: SongsEmptyKind.noTracks);
            }
            return ListView.builder(
              controller: _scroll,
              // Measured from a row, so larger text sizes do not clip rows.
              prototypeItem: SongTile(song: _prototypeSong, onTap: () {}),
              itemCount: songs.length,
              itemBuilder: (context, i) =>
                  SongTile(song: songs[i], onTap: () => _play(songs, i)),
            );
          },
        );
  }
}
