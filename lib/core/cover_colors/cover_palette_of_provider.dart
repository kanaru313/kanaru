import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/cover_color_queries.dart';
import '../database/library_startup.dart';
import 'cover_palette.dart';
import 'rust_cover_color_extractor.dart';

final _log = Logger('cover_colors');

/// The colors of cover [key] (a cover key, `<ab>/<hash>.jpg`), for a page
/// that shows that cover, such as an album page: the stored ones, else
/// worked out from the thumbnail and stored. The page checks "colors from
/// the cover" before asking, so with it off nothing is read. `null` when
/// there is no library or the colors cannot be had (logged, not thrown).
final coverPaletteOfProvider = FutureProvider.autoDispose
    .family<CoverPalette?, String>((ref, key) async {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return null;
      // Read before the first await: the ref may be disposed by then.
      final extractor = ref.read(coverColorExtractorProvider);
      try {
        final stored = await db.coverPaletteOf(key);
        if (stored != null) return stored;
        final samples = await extractor.extract([key], background: false);
        final sample = samples.where((s) => s.key == key && s.ok).firstOrNull;
        if (sample == null) return null;
        await db.upsertCoverColors([sample]);
        return paletteFromRow(
          seed: sample.seed,
          palette: encodePalette(
            sample.palette.take(maxPaletteColors).toList(),
          ),
        );
      } catch (error, stackTrace) {
        _log.warning(
          'Could not get the cover colors of $key',
          error,
          stackTrace,
        );
        return null;
      }
    }, retry: (_, _) => null);
