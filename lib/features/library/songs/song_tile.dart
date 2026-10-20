import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/indexer/cover_paths.dart';
import '../../../shared/format_duration.dart';
import '../../../shared/widgets/cover_art.dart';

/// Side of the cover at the start of a song row.
const songCoverSize = 40.0;

/// One row of the songs list: cover, title, "artist · album" and the
/// duration. Without a cover the row shows a music note.
class SongTile extends ConsumerWidget {
  const SongTile({super.key, required this.song, required this.onTap});

  final TrackListItem song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final details = [
      song.artist,
      song.album,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final durationMs = song.durationMs;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      leading: CoverArt(
        path: coverPath(ref.watch(coverCacheDirectoryProvider), song.coverKey),
        size: songCoverSize,
        placeholder: const Center(child: Icon(Icons.music_note_outlined)),
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
  }
}
