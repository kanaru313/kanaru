import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart' show AlbumKey;
import '../../core/database/library_startup.dart';
import '../../core/indexer/cover_paths.dart';
import '../icons/app_icons.dart';
import 'cover_art.dart';
import 'placeholder_colors.dart';

/// Square cover of an album: its thumbnail when it has one, else a colored
/// placeholder whose color is picked from the album key, so an album keeps
/// its color across launches.
class AlbumArtwork extends ConsumerWidget {
  const AlbumArtwork({
    super.key,
    required this.albumKey,
    required this.size,
    this.coverKey,
    this.radius,
  });

  final AlbumKey albumKey;
  final double size;

  /// The album's cover key; null shows the placeholder.
  final String? coverKey;

  /// Corner radius; null keeps the [CoverArt] default.
  final double? radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (background, foreground) = placeholderColors(
      Theme.of(context).colorScheme,
      '${albumKey.artistKey}\u0000${albumKey.titleKey}',
    );

    return CoverArt(
      path: coverPath(ref.watch(coverCacheDirectoryProvider), coverKey),
      size: size,
      radius: radius,
      placeholder: ColoredBox(
        color: background,
        child: Icon(AppIcons.album, size: size * 0.4, color: foreground),
      ),
    );
  }
}
