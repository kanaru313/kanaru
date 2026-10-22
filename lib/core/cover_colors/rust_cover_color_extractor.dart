import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../src/rust/api/cover_colors.dart' as native;
import '../database/library_startup.dart';
import '../native/rust_library.dart';
import 'cover_color_extractor.dart';

/// [CoverColorExtractor] backed by the Rust color code. The native library
/// loads on the first call. With no cover folder ([coverDirectory] `null`)
/// every key fails and nothing native is called.
class RustCoverColorExtractor implements CoverColorExtractor {
  const RustCoverColorExtractor({required this.coverDirectory});

  final String? coverDirectory;

  @override
  Future<List<CoverColorSample>> extract(
    List<String> keys, {
    required bool background,
  }) async {
    final directory = coverDirectory;
    if (directory == null || keys.isEmpty) {
      return [for (final key in keys) CoverColorSample(key: key, ok: false)];
    }
    await ensureRustLibraryLoaded();
    final results = await native.extractCoverColors(
      coverDir: directory,
      keys: keys,
      background: background,
    );
    return [for (final result in results) sampleFromNative(result)];
  }
}

/// A native result as a [CoverColorSample].
CoverColorSample sampleFromNative(native.CoverColorResult result) {
  final ok = result.status == native.CoverColorStatus.done;
  return CoverColorSample(
    key: result.key,
    ok: ok,
    seed: ok ? result.seed : 0,
    palette: ok ? List<int>.of(result.palette) : const [],
  );
}

/// The app's cover color extractor, reading thumbnails from the cover folder.
final coverColorExtractorProvider = Provider<CoverColorExtractor>(
  (ref) => RustCoverColorExtractor(
    coverDirectory: ref.watch(coverCacheDirectoryProvider),
  ),
);
