import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/song_row.dart';
import '../../core/indexer/cover_paths.dart';
import '../../core/player/playing_track_path.dart';
import '../song_modal/open_song_modal.dart';
import '../song_modal/song_modal_extras.dart';
import 'context_menu_more_button.dart';
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
/// card, its texts in `onPrimaryContainer` and an equalizer on the cover.
/// Every row is a rounded card of `songCardExtent` (see [SongRowView], which
/// draws the row, and `SongCardFrame`).
class SongTile extends ConsumerWidget {
  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.onQueueAction,
    this.modalExtras,
    this.number,
    this.leadingAccessory,
    this.detail,
    this.badge,
    this.playing,
  }) : assert(
         number == null || leadingAccessory == null,
         'number and leadingAccessory both fill the slot before the cover',
       );

  final SongRow song;

  /// Tap on the row. Null: the row is not tappable, and not focusable
  /// through its ink either, so the Menu key needs another focus stop (the ⋮
  /// button still is one when [onQueueAction] is set).
  final VoidCallback? onTap;

  /// Picked from the song modal (right click, long press or the ⋮ button);
  /// no modal and no ⋮ without it.
  final ValueChanged<QueueAction>? onQueueAction;

  /// What the screen adds to the song modal (actions, header note, left-out
  /// links), built when it opens. The single way a screen shapes the modal.
  final SongModalExtrasBuilder? modalExtras;

  /// Shown right-aligned in a column before the cover (a track number on an
  /// album page; empty keeps the column); no column when null.
  final String? number;

  /// Drawn before the cover, e.g. a drag handle; replaces [number], so not
  /// both. Nothing is added when null.
  final Widget? leadingAccessory;

  /// Shown as the third line instead of "album • year"; null keeps it.
  final String? detail;

  /// Drawn at the top of the trailing column, above the duration (see
  /// [SongRowView.badge]). The caller styles it with `labelSmall` (the row
  /// height fit depends on it), picks a contrast-safe colour on a playing row
  /// and supplies its own semantics or tooltip.
  final Widget? badge;

  /// Whether the row is marked as playing. Null: the row of the playing
  /// track is. Set by a list that already knows, e.g. one where the same song
  /// repeats and only one copy is marked, or one that watches the playing
  /// track itself for other parts of the row.
  final bool? playing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool playing =
        this.playing ??
        ref.watch(playingTrackPathProvider.select((p) => p == song.path));
    final durationMs = song.durationMs;
    final onQueue = onQueueAction;
    return TrackActionsRegion(
      song: song,
      onQueueAction: onQueue,
      modalExtras: modalExtras,
      child: SongRowView(
        title: song.title,
        artist: song.artist,
        detail: detail ?? joinRowDetails([song.album, rowYear(song.year)]),
        badge: badge,
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
        more: onQueue == null
            ? null
            : ContextMenuMoreButton(
                onOpen: ({required viaKeyboard, required at}) => openSongModal(
                  context,
                  ref,
                  song: song,
                  onQueueAction: onQueue,
                  viaKeyboard: viaKeyboard,
                  extras: modalExtras?.call() ?? const SongModalExtras(),
                ),
                color: playing
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : null,
              ),
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
