import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart';
import '../../core/database/library_startup.dart';
import '../../core/indexer/cover_paths.dart';
import '../../core/player/playing_track_path.dart';
import '../format_duration.dart';
import 'favorite_button.dart';
import 'library_row.dart';
import 'queue_actions_menu.dart';
import 'song_tile_cover.dart';
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
/// and its constant type keeps the row's elements when the flag flips.
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final base = libraryRowStyles(theme);
    final styles = playing
        ? (
            title: base.title.copyWith(color: colors.onPrimaryContainer),
            detail: base.detail.copyWith(color: colors.onPrimaryContainer),
          )
        : base;
    final albumLine = joinRowDetails([song.album, rowYear(song.year)]);
    final durationMs = song.durationMs;

    final number = this.number;
    final leadingAccessory = this.leadingAccessory;
    final trailingAccessory = this.trailingAccessory;
    final cover = SongTileCover(
      path: coverPath(ref.watch(coverCacheDirectoryProvider), song.coverKey),
      playing: playing,
    );

    final trailingColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (durationMs != null)
          Text(
            formatDuration(Duration(milliseconds: durationMs)),
            style: styles.detail,
          ),
        FavoriteButton(
          path: song.path,
          iconSize: 20,
          compact: true,
          color: playing ? colors.onPrimaryContainer : null,
        ),
      ],
    );

    final tile = Material(
      color: playing ? colors.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: LibraryRowLayout(
          leading: leadingAccessory != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16,
                  children: [leadingAccessory, cover],
                )
              : number == null
              ? cover
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16,
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        number,
                        textAlign: TextAlign.end,
                        style: styles.detail,
                      ),
                    ),
                    cover,
                  ],
                ),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              libraryRowLine(song.title, styles.title),
              libraryRowLine(song.artist ?? '', styles.detail),
              libraryRowLine(albumLine, styles.detail),
            ],
          ),
          trailing: trailingAccessory == null
              ? trailingColumn
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [trailingColumn, trailingAccessory],
                ),
        ),
      ),
    );
    return TrackActionsRegion(
      trackId: song.id,
      path: song.path,
      showAlbum: showAlbum,
      hasArtist: song.artist?.isNotEmpty ?? false,
      hasAlbum: song.album?.isNotEmpty ?? false,
      onQueueAction: onQueueAction,
      child: tile,
    );
  }
}
