import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../shared/format_duration.dart';

/// One track of an album page: number, title, the track artist when it is
/// not the album artist, and the duration.
class AlbumTrackTile extends StatelessWidget {
  const AlbumTrackTile({
    super.key,
    required this.track,
    required this.albumArtist,
    required this.onTap,
  });

  final BrowseTrack track;

  /// Shown in the header; a track by the same artist does not repeat it.
  final String? albumArtist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final artist = track.artist;
    final durationMs = track.durationMs;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      leading: SizedBox(
        width: 32,
        child: Text(
          track.trackNo?.toString() ?? '',
          textAlign: TextAlign.end,
          style: muted,
        ),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: artist == null || artist == albumArtist
          ? null
          : Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: durationMs == null
          ? null
          : Text(
              formatDuration(Duration(milliseconds: durationMs)),
              style: muted,
            ),
      onTap: onTap,
    );
  }
}
