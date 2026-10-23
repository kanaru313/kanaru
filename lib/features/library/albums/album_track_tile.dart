import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/indexer/cover_paths.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../shared/format_duration.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../../../shared/widgets/song_tile.dart' show songCoverSize;
import '../../../shared/widgets/track_actions_menu.dart';

/// One track of an album page: number (or the track's cover when track
/// numbers are turned off in Settings), title, the track artist when it is
/// not the album artist, and the duration.
class AlbumTrackTile extends ConsumerWidget {
  const AlbumTrackTile({
    super.key,
    required this.track,
    required this.albumArtist,
    required this.onTap,
    this.onQueueAction,
  });

  final BrowseTrack track;

  /// Shown in the header; a track by the same artist does not repeat it.
  final String? albumArtist;
  final VoidCallback onTap;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final artist = track.artist;
    final durationMs = track.durationMs;

    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      leading:
          ref.watch(
            settingsProvider.select((s) => s.display.trackNumbersInAlbum),
          )
          ? SizedBox(
              width: 32,
              child: Text(
                track.trackNo?.toString() ?? '',
                textAlign: TextAlign.end,
                style: muted,
              ),
            )
          : CoverArt(
              path: coverPath(
                ref.watch(coverCacheDirectoryProvider),
                track.coverKey,
              ),
              size: songCoverSize,
              placeholder: const Center(
                child: Icon(AppIcons.musicNoteOutlined),
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
    return TrackActionsRegion(
      trackId: track.id,
      path: track.path,
      showAlbum: false,
      hasArtist: artist?.isNotEmpty ?? false,
      onQueueAction: onQueueAction,
      child: tile,
    );
  }
}
