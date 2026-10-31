import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_rows.dart';
import '../../core/database/library_startup.dart';
import '../../core/indexer/cover_paths.dart';
import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import '../widgets/cover_art.dart';

const double _coverSize = 56;

/// Top of the song modal: the cover, then the artists line, the title and
/// the album, and the screen's [note] when it has one. With [onTap] the
/// header opens the song's details and shows a chevron.
class SongModalHeader extends ConsumerWidget {
  const SongModalHeader({super.key, required this.song, this.onTap, this.note});

  final TrackListItem song;
  final VoidCallback? onTap;

  /// Extra quiet fourth line (set by the screen); null leaves three lines.
  final String? note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final quiet = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final artist = song.artist ?? '';
    final album = song.album;
    final cover = coverPath(
      ref.watch(coverCacheDirectoryProvider),
      song.coverKey,
    );
    Widget line(String text, TextStyle? style) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        spacing: 16,
        children: [
          CoverArt(
            path: cover,
            size: _coverSize,
            placeholder: const Center(child: Icon(AppIcons.musicNoteOutlined)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (artist.isNotEmpty) line(artist, quiet),
                line(song.title, theme.textTheme.titleMedium),
                line(
                  album == null || album.isEmpty
                      ? context.l10n.songModalUnknownAlbum
                      : album,
                  quiet,
                ),
                if (note != null) line(note!, quiet),
              ],
            ),
          ),
          if (onTap != null) const Icon(AppIcons.chevronRight),
        ],
      ),
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}
