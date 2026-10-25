import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_browse_now_playing.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/playing_track_art.dart' show localPathOf;
import '../../../shared/icons/app_icons.dart';
import '../../../shared/library_route_keys.dart';
import 'now_playing_line_icon.dart';
import 'now_playing_open_provider.dart';

final _log = Logger('now_playing');

/// The album of the playing library file; null when nothing plays, the file
/// is not in the library or it has no album. While the next song's album is
/// looked up the previous value stays, so the line does not blink between
/// songs of one album; a failed lookup gives null, never the old album.
final nowPlayingAlbumProvider = FutureProvider.autoDispose<NowPlayingAlbum?>((
  ref,
) async {
  final uri = ref.watch(
    playerServiceProvider.select((s) => s.queue.current?.uri),
  );
  final path = uri == null ? null : localPathOf(uri);
  if (path == null) return null;
  try {
    return await ref.watch(libraryDatabaseProvider)?.albumOfPath(path);
  } on Object catch (error, stack) {
    // An error state would keep the previous song's album on screen.
    _log.warning('Reading the album of $path failed', error, stack);
    return null;
  }
});

/// Album of the playing song, in the style of the artist line above it. Taps
/// close Now Playing and open the album page; without a router or an album
/// key it is plain text. Shows nothing for a file outside the library or
/// without an album, and until the first lookup is done.
class NowPlayingAlbumLine extends ConsumerWidget {
  const NowPlayingAlbumLine({
    super.key,
    required this.centered,
    this.leadingIcon,
    this.padded = true,
    this.showIcon = true,
  });

  /// Centers the line; otherwise it starts at the left.
  final bool centered;

  /// An icon in front of the line, outside the tap target. Without it the
  /// line carries its own small icon inside the tap target.
  final IconData? leadingIcon;

  /// Keeps a gap of 8 px above the line (none for a song without album) and
  /// fills the width. Without it the line is only as large as its content,
  /// for a caller that places it beside other text.
  final bool padded;

  /// Whether the line carries its own small icon; off for plain text.
  final bool showIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = ref.watch(nowPlayingAlbumProvider).value;
    if (album == null) return const SizedBox.shrink();

    final router = GoRouter.maybeOf(context);
    final key = album.key;
    final line = Opacity(
      opacity: 0.7,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          if (leadingIcon == null && showIcon)
            const Icon(AppIcons.album, size: 20),
          Flexible(
            child: Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
    final Widget linked = router == null || key == null
        ? line
        : InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              ref.read(nowPlayingOpenProvider.notifier).close();
              router.go(albumLocation(key));
            },
            child: line,
          );
    final aligned = Align(
      alignment: centered ? Alignment.center : Alignment.centerLeft,
      widthFactor: padded ? null : 1,
      heightFactor: padded ? null : 1,
      child: leadingIcon == null
          ? linked
          : NowPlayingLineWithIcon(icon: leadingIcon!, line: linked),
    );
    // The gap lives here so a song without album adds no space.
    return padded
        ? Padding(padding: const EdgeInsets.only(top: 8), child: aligned)
        : aligned;
  }
}
