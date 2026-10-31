import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart' show TrackListItem;
import '../../core/database/library_startup.dart';
import '../../core/indexer/cover_paths.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/cover_art.dart';
import '../../shared/widgets/track_actions_menu.dart';
import 'home_tile_metrics.dart';
import '../../shared/fixed_line_strut.dart';

/// One song on a shelf: square cover, title and artist. Tapping plays the
/// whole [row] from this song.
class HomeTrackCard extends ConsumerWidget {
  const HomeTrackCard({super.key, required this.row, required this.index});

  /// The songs on the shelf; the queue made by a tap.
  final List<TrackListItem> row;

  /// Position of this card's song in [row].
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final song = row[index];
    final artist = song.artist;
    final covers = ref.watch(coverCacheDirectoryProvider);
    final tile = InkWell(
      onTap: () => playTracks(ref, [
        for (final t in row) trackFromListItem(t, covers),
      ], index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(homeCardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(
              path: coverPath(covers, song.coverKey),
              size: homeCardPictureSize,
              placeholder: ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: Icon(AppIcons.musicNoteOutlined, size: 40),
                ),
              ),
            ),
            const SizedBox(height: homeCardGap),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
              strutStyle: fixedLineStrut(theme.textTheme.titleSmall),
            ),
            Text(
              artist ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              strutStyle: fixedLineStrut(theme.textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
    return TrackActionsRegion(
      song: song,
      onQueueAction: (action) => enqueueLoaded(ref, context, action, [
        trackFromListItem(song, covers),
      ], song.title),
      child: tile,
    );
  }
}
