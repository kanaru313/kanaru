import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/indexer/cover_paths.dart';
import '../icons/app_icons.dart';
import 'cover_art.dart';
import 'placeholder_colors.dart';

/// Square cover of a playlist: its first one to four distinct covers as a
/// collage (one full, two side-by-side halves, three as a left half plus two
/// right quarters, four as a 2x2 grid), else a colored placeholder picked
/// from [seed], so a playlist keeps its color across launches.
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
    // tiles of bare color. One cover fills the whole square.
    if (paths.length < 2) {
      return CoverArt(
        path: paths.firstOrNull,
        size: size,
        radius: radius,
        placeholder: ColoredBox(
          color: background,
          child: Icon(AppIcons.playlist, size: size * 0.4, color: foreground),
        ),
      );
    }

    final half = size / 2;
    Widget tile(String path, double width, double height) => _CollageTile(
      path: path,
      width: width,
      height: height,
      placeholder: ColoredBox(color: background),
    );
    final Widget collage = switch (paths.length) {
      2 => Row(
        children: [tile(paths[0], half, size), tile(paths[1], half, size)],
      ),
      3 => Row(
        children: [
          tile(paths[0], half, size),
          Column(
            children: [tile(paths[1], half, half), tile(paths[2], half, half)],
          ),
        ],
      ),
      _ => Column(
        children: [
          Row(
            children: [tile(paths[0], half, half), tile(paths[1], half, half)],
          ),
          Row(
            children: [tile(paths[2], half, half), tile(paths[3], half, half)],
          ),
        ],
      ),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? (size < 64 ? 4 : 8)),
      child: SizedBox.square(dimension: size, child: collage),
    );
  }
}

/// One cell of the collage. Covers are square, so the cover is drawn square
/// at the cell's largest side (decoded at that size, like [CoverArt]) and
/// the overflow is cropped around the center, which is a cover-fit.
class _CollageTile extends StatelessWidget {
  const _CollageTile({
    required this.path,
    required this.width,
    required this.height,
    required this.placeholder,
  });

  final String path;
  final double width;
  final double height;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    final side = width > height ? width : height;
    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: OverflowBox(
          minWidth: side,
          maxWidth: side,
          minHeight: side,
          maxHeight: side,
          child: CoverArt(
            path: path,
            size: side,
            radius: 0,
            placeholder: placeholder,
          ),
        ),
      ),
    );
  }
}
