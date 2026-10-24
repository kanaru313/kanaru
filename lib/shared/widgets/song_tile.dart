import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart';
import '../../core/database/library_startup.dart';
import '../../core/indexer/cover_paths.dart';
import '../format_duration.dart';
import '../icons/app_icons.dart';
import 'cover_art.dart';
import 'favorite_button.dart';
import 'queue_actions_menu.dart';
import 'track_actions_menu.dart';

/// Side of the cover at the start of a compact song row (history,
/// playlist and album track rows).
const songCoverSize = 40.0;

/// Side of the cover at the start of a [SongTile].
const songTileCoverSize = 64.0;

/// Smallest height of a [SongTile] and its placeholder, so both measure the
/// same: the cover plus 8 px above and below.
const _songTileMinHeight = songTileCoverSize + 16;

/// Joins the parts of a details line; the same dot in every row.
String _joinDetails(Iterable<String?> parts) =>
    parts.whereType<String>().where((s) => s.isNotEmpty).join(' • ');

/// The layout shared by [SongTile] and [SongTilePlaceholder]: [leading],
/// then [body] taking the free width, then [trailing]. Not a `ListTile`,
/// which caps its leading at 56 px high and would squash the cover.
class _SongRowLayout extends StatelessWidget {
  const _SongRowLayout({
    required this.leading,
    required this.body,
    this.trailing,
  });

  final Widget leading;
  final Widget body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: _songTileMinHeight),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Row(
        spacing: 16,
        children: [
          leading,
          Expanded(child: body),
          ?trailing,
        ],
      ),
    ),
  );
}

/// One song row: cover, then three lines (title, artist, "album • year"),
/// then the duration above a heart. Without a cover the row shows a music
/// note. Every line is always laid out, empty or not, so all rows have the
/// height of the list's prototype row.
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
    final colors = theme.colorScheme;
    final detailStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final albumLine = _joinDetails([song.album, song.year?.toString()]);
    final durationMs = song.durationMs;

    // The strut holds each line at the style's own height, so a fallback
    // font (CJK titles) cannot make a row taller than the prototype row.
    Widget line(String text, TextStyle? style) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
      strutStyle: style == null
          ? null
          : StrutStyle.fromTextStyle(style, forceStrutHeight: true),
    );

    final tile = InkWell(
      onTap: onTap,
      child: _SongRowLayout(
        leading: CoverArt(
          path: coverPath(
            ref.watch(coverCacheDirectoryProvider),
            song.coverKey,
          ),
          size: songTileCoverSize,
          placeholder: const Center(child: Icon(AppIcons.musicNoteOutlined)),
        ),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line(
              song.title,
              theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            line(song.artist ?? '', detailStyle),
            line(albumLine, detailStyle),
          ],
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (durationMs != null)
              Text(
                formatDuration(Duration(milliseconds: durationMs)),
                style: detailStyle,
              ),
            FavoriteButton(path: song.path, iconSize: 20, compact: true),
          ],
        ),
      ),
    );
    return TrackActionsRegion(
      trackId: song.id,
      path: song.path,
      hasArtist: song.artist?.isNotEmpty ?? false,
      hasAlbum: song.album?.isNotEmpty ?? false,
      onQueueAction: onQueueAction,
      child: tile,
    );
  }
}

/// A song row whose data is still being read: same height as [SongTile],
/// with bars where the texts go. [compact] matches the two-line rows of
/// [songCoverSize] instead (history).
class SongTilePlaceholder extends StatelessWidget {
  const SongTilePlaceholder({super.key, this.compact = false});

  final bool compact;

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
    Widget cover(double size) => SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
    if (compact) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 32),
        leading: cover(songCoverSize),
        title: Align(alignment: Alignment.centerLeft, child: bar(180)),
        subtitle: Align(alignment: Alignment.centerLeft, child: bar(120)),
      );
    }
    return _SongRowLayout(
      leading: cover(songTileCoverSize),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [bar(180), bar(120), bar(150)],
      ),
    );
  }
}
