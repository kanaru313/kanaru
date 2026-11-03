import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/song_row.dart';
import '../../core/indexer/cover_paths.dart';
import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import '../widgets/context_modal/context_modal_header.dart';
import '../widgets/cover_art.dart';

const double _coverSize = 64;

/// Top of the song modal: the cover, then the artists line, the title and
/// the album, and the screen's [note] when it has one. With [onTap] the
/// header opens the song's details and shows a chevron.
class SongModalHeader extends ConsumerWidget {
  const SongModalHeader({super.key, required this.song, this.onTap, this.note});

  final SongRow song;
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
    return ContextModalHeader(
      leading: CoverArt(
        path: cover,
        size: _coverSize,
        placeholder: const Center(child: Icon(AppIcons.musicNoteOutlined)),
      ),
      lines: [
        if (artist.isNotEmpty) contextModalHeaderLine(artist, quiet),
        contextModalHeaderLine(song.title, theme.textTheme.titleMedium),
        contextModalHeaderLine(
          album == null || album.isEmpty
              ? context.l10n.songModalUnknownAlbum
              : album,
          quiet,
        ),
        if (note != null) contextModalHeaderLine(note!, quiet),
      ],
      trailing: onTap == null ? null : const Icon(AppIcons.chevronRight),
      onTap: onTap,
      tapHint: context.l10n.songInfoTitle,
      // The only keyboard path to Song info: the actions page has no such row.
      canRequestFocus: true,
    );
  }
}
