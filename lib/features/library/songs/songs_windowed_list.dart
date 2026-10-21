import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart' show TrackListItem;
import '../../../core/database/library_song_paging.dart';
import '../../../core/database/library_startup.dart';
import '../widgets/library_rescan_button.dart';
import '../widgets/queue_actions_menu.dart';
import 'song_row_cache.dart';
import 'song_tile.dart';
import 'songs_list_provider.dart';

/// Row used to measure the list: two lines and a duration, the tallest a
/// row gets, so rows without an artist are not squeezed.
const prototypeSong = TrackListItem(
  id: 0,
  path: '',
  title: 'Title',
  artist: 'Artist',
  durationMs: 1000,
);

/// The Songs list for [songs]: one slot per id, so any position of a large
/// library can be scrolled to, with rows read a page at a time as they come
/// into view (see [SongRowCache]) and a placeholder until then. [seed] rows,
/// read before the ids, show without waiting.
class SongsWindowedList extends ConsumerStatefulWidget {
  const SongsWindowedList({
    super.key,
    required this.songs,
    required this.controller,
    required this.onTap,
    this.onQueueAction,
    this.seed = const [],
  });

  final SongIds songs;
  final ScrollController controller;

  /// A row was tapped: the track id, not its position, which may change.
  final void Function(int trackId) onTap;

  /// An action picked from the menu of a row; no menus without it.
  final void Function(TrackListItem song, QueueAction action)? onQueueAction;
  final List<TrackListItem> seed;

  @override
  ConsumerState<SongsWindowedList> createState() => _SongsWindowedListState();
}

class _SongsWindowedListState extends ConsumerState<SongsWindowedList> {
  late final SongRowCache _cache;

  @override
  void initState() {
    super.initState();
    _cache = SongRowCache(
      load: (ids) async {
        final db = ref.read(libraryDatabaseProvider);
        return db == null ? const [] : db.songsByIds(ids);
      },
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    _cache.seed(widget.seed);
    _cache.setIds(widget.songs.ids);
  }

  @override
  void didUpdateWidget(SongsWindowedList old) {
    super.didUpdateWidget(old);
    // A new sort brings the first page of its order with it.
    _cache.seed(widget.seed);
    _cache.setIds(widget.songs.ids);
  }

  @override
  void dispose() {
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.controller,
      padding: const EdgeInsets.only(bottom: libraryRescanClearance),
      // Measured from a row, so larger text sizes do not clip rows.
      prototypeItem: SongTile(song: prototypeSong, onTap: () {}),
      itemCount: widget.songs.ids.length,
      itemBuilder: (context, i) {
        final song = _cache.rowAt(i);
        if (song == null) return const SongTilePlaceholder();
        final onQueueAction = widget.onQueueAction;
        return SongTile(
          song: song,
          onTap: () => widget.onTap(song.id),
          onQueueAction: onQueueAction == null
              ? null
              : (action) => onQueueAction(song, action),
        );
      },
    );
  }
}
