import '../database/library_database.dart' show TracksCompanion;
import 'walk_audio_files.dart';

/// Files read this session and found shorter than the minimum length, so an
/// unchanged one is not read again on every scan. Lives as long as the
/// indexer; a file that changed (mtime or size) is read again.
class ShortTrackMemo {
  final _seen = <String, ({int mtimeMs, int sizeBytes, int durationMs})>{};

  /// Whether [file] is unchanged since it was found shorter than [minMs].
  bool skips(WalkedFile file, int minMs) {
    if (minMs <= 0) return false;
    final seen = _seen[file.path];
    return seen != null &&
        seen.mtimeMs == file.mtimeMs &&
        seen.sizeBytes == file.sizeBytes &&
        seen.durationMs < minMs;
  }

  void remember(WalkedFile file, int durationMs) => _seen[file.path] = (
    mtimeMs: file.mtimeMs,
    sizeBytes: file.sizeBytes,
    durationMs: durationMs,
  );

  void forget(String path) => _seen.remove(path);

  /// Splits [rows] (one per file of [files], in order) into those to store
  /// and the paths of tracks shorter than [minMs], which are remembered. A
  /// row without a duration (tags failed, or the reader found none) is kept.
  ({List<TracksCompanion> kept, List<String> shortPaths}) splitShort(
    List<WalkedFile> files,
    List<TracksCompanion> rows,
    int minMs,
  ) {
    final kept = <TracksCompanion>[], shortPaths = <String>[];
    for (var i = 0; i < rows.length; i++) {
      final duration = rows[i].durationMs.value;
      if (minMs > 0 && duration != null && duration < minMs) {
        remember(files[i], duration);
        shortPaths.add(files[i].path);
      } else {
        forget(files[i].path);
        kept.add(rows[i]);
      }
    }
    return (kept: kept, shortPaths: shortPaths);
  }
}
