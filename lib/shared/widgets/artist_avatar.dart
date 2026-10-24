import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/indexer/cover_paths.dart';
import '../artist_covers_provider.dart';
import 'cover_art.dart';
import 'placeholder_colors.dart';

/// Round picture of an artist: the cover of its first album (see
/// [artistCoversProvider]), else the first letter of [name] on a color
/// picked from [artistKey], the same on every launch.
class ArtistAvatar extends ConsumerWidget {
  const ArtistAvatar({
    super.key,
    required this.artistKey,
    required this.name,
    required this.size,
  });

  final String artistKey;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverKey = ref.watch(
      artistCoversProvider.select((covers) => covers.value?[artistKey]),
    );
    final (background, foreground) = placeholderColors(
      Theme.of(context).colorScheme,
      artistKey,
    );
    final initial = name.characters.firstOrNull?.toUpperCase() ?? '';

    return CoverArt(
      path: coverPath(ref.watch(coverCacheDirectoryProvider), coverKey),
      size: size,
      radius: size / 2,
      placeholder: CircleAvatar(
        radius: size / 2,
        backgroundColor: background,
        foregroundColor: foreground,
        child: Text(
          initial,
          style: TextStyle(fontSize: size * 0.4),
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }
}
