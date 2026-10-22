import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../database/cover_color_queries.dart';
import '../database/library_startup.dart';
import '../player/cover_path_in_directory.dart';
import '../player/playing_track_art.dart';
import '../settings/settings_provider.dart';
import 'cover_palette.dart';
import 'rust_cover_color_extractor.dart';

final _log = Logger('cover_colors');

/// How long the player waits for the colors of the cover that just started.
const playingCoverColorTimeout = Duration(seconds: 2);

/// Cover keys whose colors could not be worked out while playing in this
/// session; they are not tried again until the app restarts.
final _failedPlayingKeysProvider = Provider<Set<String>>((ref) => <String>{});

/// The colors of the playing track's cover, when "colors from the cover" is
/// on: the stored ones, else worked out from the thumbnail right away and
/// stored. `null` when the setting is off, nothing plays, the art is not one
/// of our thumbnails, or the colors cannot be had (logged, not thrown).
///
/// Reads the setting before anything else, so with the setting off it
/// touches neither the player, the database nor the native code.
final playingCoverPaletteProvider = FutureProvider<CoverPalette?>((ref) async {
  final on = ref.watch(
    settingsProvider.select((s) => s.display.colorFromCover),
  );
  if (!on) return null;
  final art = ref.watch(playingTrackArtProvider);
  final directory = ref.watch(coverCacheDirectoryProvider);
  final db = ref.watch(libraryDatabaseProvider);
  if (directory == null || db == null || !isCoverPathIn(directory, art)) {
    return null;
  }
  final key = art!.substring(directory.length + 1);
  final failed = ref.read(_failedPlayingKeysProvider);
  // Read before the first await: once the track changes or the setting goes
  // off, this run is stale and its ref unusable.
  final extractor = ref.read(coverColorExtractorProvider);
  try {
    final stored = await db.coverPaletteOf(key);
    if (stored != null || failed.contains(key) || !ref.mounted) return stored;
    final samples = await extractor
        .extract([key], background: false)
        .timeout(playingCoverColorTimeout);
    // A stale run stores nothing: the setting may be off by now.
    if (!ref.mounted) return null;
    final sample = samples.where((s) => s.key == key && s.ok).firstOrNull;
    if (sample == null) {
      failed.add(key);
      return null;
    }
    await db.upsertCoverColors([sample]);
    return paletteFromRow(
      seed: sample.seed,
      palette: encodePalette(sample.palette.take(maxPaletteColors).toList()),
    );
  } on TimeoutException {
    if (ref.mounted) failed.add(key);
    _log.warning('Cover colors took over $playingCoverColorTimeout: $key');
    return null;
  } catch (error, stackTrace) {
    if (ref.mounted) failed.add(key);
    _log.warning('Could not get the cover colors of $key', error, stackTrace);
    return null;
  }
}, retry: (_, _) => null);

/// The cover colors the app shows: follows [playingCoverPaletteProvider],
/// but keeps the previous colors while the next ones load, so a track
/// change goes from one cover's colors straight to the next one's. `null`
/// (the system accent, no Now Playing gradient) once the answer is "no
/// colors".
class AppCoverPaletteNotifier extends Notifier<CoverPalette?> {
  @override
  CoverPalette? build() {
    ref.listen(playingCoverPaletteProvider, (_, next) {
      if (next is AsyncData<CoverPalette?>) state = next.value;
    });
    return ref.read(playingCoverPaletteProvider).value;
  }
}

final appCoverPaletteProvider =
    NotifierProvider<AppCoverPaletteNotifier, CoverPalette?>(
      AppCoverPaletteNotifier.new,
    );
