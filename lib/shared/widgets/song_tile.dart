import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart';
import '../../core/database/library_startup.dart';
import '../../core/indexer/cover_paths.dart';
import '../format_duration.dart';
import '../icons/app_icons.dart';
import 'cover_art.dart';
import 'queue_actions_menu.dart';

/// Side of the cover at the start of a song row.
const songCoverSize = 40.0;

/// One song row: cover, title, "artist · album" and the
/// duration. Without a cover the row shows a music note.
class SongTile extends ConsumerWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onQueueAction,
  });

  final TrackListItem song;
  final VoidCallback onTap;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final details = [
      song.artist,
      song.album,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final durationMs = song.durationMs;

    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      leading: CoverArt(
        path: coverPath(ref.watch(coverCacheDirectoryProvider), song.coverKey),
        size: songCoverSize,
        placeholder: const Center(child: Icon(AppIcons.musicNoteOutlined)),
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: details.isEmpty
          ? null
          : Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: durationMs == null
          ? null
          : Text(
              formatDuration(Duration(milliseconds: durationMs)),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      onTap: onTap,
    );
    return QueueActionsRegion(onAction: onQueueAction, child: tile);
  }
}

/// A song row whose data is still being read: same height as [SongTile],
/// with bars where the texts go.
class SongTilePlaceholder extends StatelessWidget {
  const SongTilePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double width) => Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      leading: SizedBox.square(
        dimension: songCoverSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      title: Align(alignment: Alignment.centerLeft, child: bar(180)),
      subtitle: Align(alignment: Alignment.centerLeft, child: bar(120)),
    );
  }
}
