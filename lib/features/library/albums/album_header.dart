import 'package:material_ui/material_ui.dart';

import '../../../core/database/artist_names.dart';
import '../../../core/database/library_database.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/format_duration.dart';
import '../widgets/album_artwork.dart';

/// The album's details as its page shows them, from its tracks, picked the
/// same way as the albums query: smallest title and artist, latest year.
class AlbumInfo {
  const AlbumInfo({
    required this.title,
    required this.trackCount,
    this.artist,
    this.year,
    this.durationMs,
  });

  factory AlbumInfo.fromTracks(List<BrowseTrack> tracks) {
    String? smallest(Iterable<String?> values) {
      String? best;
      for (final value in values) {
        if (value != null && (best == null || value.compareTo(best) < 0)) {
          best = value;
        }
      }
      return best;
    }

    final years = tracks.map((t) => t.year).whereType<int>();
    final durations = tracks.map((t) => t.durationMs).whereType<int>();
    return AlbumInfo(
      title: smallest(tracks.map((t) => t.album)) ?? '',
      artist: smallest(
        tracks.map((t) => t.albumArtist ?? splitArtists(t.artist).firstOrNull),
      ),
      year: years.isEmpty ? null : years.reduce((a, b) => a > b ? a : b),
      trackCount: tracks.length,
      durationMs: durations.isEmpty ? null : durations.reduce((a, b) => a + b),
    );
  }

  final String title;
  final String? artist;
  final int? year;
  final int trackCount;
  final int? durationMs;
}

/// Artwork, title, artist, "year · N songs · duration" and a Play button.
class AlbumHeader extends StatelessWidget {
  const AlbumHeader({
    super.key,
    required this.albumKey,
    required this.info,
    required this.onPlay,
    this.artist,
  });

  final AlbumKey albumKey;
  final AlbumInfo info;
  final VoidCallback onPlay;

  /// Replaces the plain artist name, for example with a link.
  final Widget? artist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final durationMs = info.durationMs;
    final details = [
      if (info.year != null) '${info.year}',
      l10n.albumsSongCount(info.trackCount),
      if (durationMs != null)
        formatDuration(Duration(milliseconds: durationMs)),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AlbumArtwork(albumKey: albumKey, size: 160),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                artist ??
                    Text(
                      info.artist ?? l10n.albumsUnknownArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(l10n.albumsPlay),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
