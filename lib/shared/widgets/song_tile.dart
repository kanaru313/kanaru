import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart';
import '../../core/database/library_startup.dart';
import '../../core/indexer/cover_paths.dart';
import '../../core/player/playing_track_path.dart';
import 'favorite_button.dart';
import 'library_row.dart';
import 'queue_actions_menu.dart';
import 'song_row_view.dart';
import 'track_actions_menu.dart';

/// Side of the cover at the start of a compact song row (history,
/// playlist and album track rows).
const songCoverSize = 40.0;

/// One song row: an optional [number] column, the cover, then three lines
/// (title, artist, "album • year"), then the duration above a heart. Without
/// a cover the row shows a music note. Every line is always laid out, empty
/// or not, so all rows have the height of the list's prototype row.
///
/// The row of the playing track (same while paused) has a `primaryContainer`
/// background, its texts in `onPrimaryContainer` and an equalizer on the
/// cover. The row always has its own canvas [Material] (transparent when not
/// playing): ink paints under it, so the fill cannot hide hover and splash,
/// and its constant type keeps the row's elements when the flag flips (see
/// [SongRowView], which draws the row).
class SongTile extends ConsumerWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onQueueAction,
    this.number,
    this.showAlbum = true,
    this.leadingAccessory,
    this.trailingAccessory,
  }) : assert(
         number == null || leadingAccessory == null,
         'number and leadingAccessory both fill the slot before the cover',
       );

  final TrackListItem song;
  final VoidCallback onTap;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  /// Shown right-aligned in a column before the cover (a track number on an
  /// album page; empty keeps the column); no column when null.
  final String? number;

  /// False leaves Show album out of the menu (rows on the album's own page).
  final bool showAlbum;

  /// Drawn before the cover, e.g. a drag handle; replaces [number], so not
  /// both. Nothing is added when null.
  final Widget? leadingAccessory;

  /// Drawn after the duration and heart column, e.g. a row action such as
  /// remove. Nothing is added when null.
  final Widget? trailingAccessory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(
      playingTrackPathProvider.select((p) => p == song.path),
    );
    final durationMs = song.durationMs;
    return TrackActionsRegion(
      trackId: song.id,
      path: song.path,
      showAlbum: showAlbum,
      hasArtist: song.artist?.isNotEmpty ?? false,
      hasAlbum: song.album?.isNotEmpty ?? false,
      onQueueAction: onQueueAction,
      child: SongRowView(
        title: song.title,
        artist: song.artist,
        detail: joinRowDetails([song.album, rowYear(song.year)]),
        coverPath: coverPath(
          ref.watch(coverCacheDirectoryProvider),
          song.coverKey,
        ),
        duration: durationMs == null
            ? null
            : Duration(milliseconds: durationMs),
        playing: playing,
        onTap: onTap,
        number: number,
        leading: leadingAccessory,
        trailing: trailingAccessory,
        heart: FavoriteButton(
          path: song.path,
          iconSize: 20,
          compact: true,
          color: playing
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : null,
        ),
      ),
    );
  }
}
