import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/indexer/cover_paths.dart';
import 'cover_art.dart';
import 'placeholder_colors.dart';

/// Square cover of a playlist: its first four distinct covers as a 2x2
/// collage, the first cover alone when there are one to three, else a
/// colored placeholder picked from [seed], so a playlist keeps its color
/// across launches.
class PlaylistCover extends ConsumerWidget {
  const PlaylistCover({
    super.key,
    required this.coverKeys,
    required this.size,
    required this.seed,
    this.radius,
  });

  /// Cover keys already picked (`pickCollageKeys`), at most four.
  final List<String> coverKeys;
  final double size;

  /// Picks the placeholder color, for example `playlist:<id>`.
  final String seed;
  final double? radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directory = ref.watch(coverCacheDirectoryProvider);
    final paths = [
      for (final key in coverKeys.take(4)) ?coverPath(directory, key),
    ];
    final (background, foreground) = placeholderColors(
      Theme.of(context).colorScheme,
      seed,
    );

    // Covers off or none resolving: one placeholder with the icon, never
    // four tiles of bare color.
    if (paths.length < 4) {
      return CoverArt(
        path: paths.firstOrNull,
        size: size,
        radius: radius,
        placeholder: ColoredBox(
          color: background,
          child: Icon(Icons.queue_music, size: size * 0.4, color: foreground),
        ),
      );
    }

    final tile = size / 2;
    Widget quarter(String path) => CoverArt(
      path: path,
      size: tile,
      radius: 0,
      placeholder: ColoredBox(color: background),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? (size < 64 ? 4 : 8)),
      child: SizedBox.square(
        dimension: size,
        child: Column(
          children: [
            Row(children: [quarter(paths[0]), quarter(paths[1])]),
            Row(children: [quarter(paths[2]), quarter(paths[3])]),
          ],
        ),
      ),
    );
  }
}
