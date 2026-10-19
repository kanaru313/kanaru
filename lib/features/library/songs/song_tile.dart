import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../shared/format_duration.dart';

/// Height of a song row. Fixed so the list can lay out without measuring.
const songTileExtent = 64.0;

/// One row of the songs list: title, "artist · album" and the duration.
class SongTile extends StatelessWidget {
  const SongTile({super.key, required this.song, required this.onTap});

  final TrackListItem song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      song.artist,
      song.album,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final durationMs = song.durationMs;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      leading: const Icon(Icons.music_note_outlined),
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
