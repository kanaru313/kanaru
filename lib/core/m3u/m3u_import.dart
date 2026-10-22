import 'dart:isolate';

import '../paths/local_audio_path.dart';
import 'm3u_parse.dart';
import 'm3u_read.dart';

/// What an M3U import found.
class M3uImportResult {
  const M3uImportResult({
    required this.paths,
    required this.duplicates,
    required this.unresolved,
    required this.total,
    required this.truncated,
  });

  /// Canonical paths of local audio files, in file order, each once.
  final List<String> paths;

  /// Lines that named a file already in [paths].
  final int duplicates;

  /// Lines that are not an existing local audio file (missing, a URL, not
  /// audio, too long), with their line number in the file.
  final List<({int line, String text})> unresolved;

  /// Path lines read (comments and blank lines not counted).
  final int total;

  /// Whether the file had more than [m3uMaxPathLines] path lines.
  final bool truncated;
}

/// Lines resolved at the same time.
const _batchSize = 32;

/// [line] as a canonical path through `localAudioPath`, or null. Never
/// throws.
Future<String?> _resolve(M3uLine line, String folder) async {
  if (line.tooLong) return null;
  try {
    return await localAudioPath(line.text, baseDirectory: folder);
  } catch (_) {
    return null;
  }
}

/// Thrown by [importM3uFile] when [cancelled] turned true.
class M3uImportCancelled implements Exception {
  const M3uImportCancelled();
}

/// Reads the M3U file at [path] (absolute) and resolves each line to a
/// library-style path.
///
/// Every line goes once through `localAudioPath`, with relative lines taken
/// from the folder of the M3U file: only existing local audio files pass;
/// URLs and other schemes never do. Nothing is guessed (no trimming, no `\`
/// to `/`): a backslash is a valid file name character on Linux.
///
/// Throws [M3uReadException] when the file cannot be read and
/// [M3uImportCancelled] when [cancelled] returns true between batches of
/// lines.
Future<M3uImportResult> importM3uFile(
  String path, {
  bool Function()? cancelled,
}) async {
  final bytes = await readM3uBytes(path);
  final parsed = await Isolate.run(() => parseM3uBytes(bytes));
  final slash = path.lastIndexOf('/');
  final folder = slash <= 0 ? '/' : path.substring(0, slash);

  final paths = <String>[];
  final seen = <String>{};
  final unresolved = <({int line, String text})>[];
  var duplicates = 0;
  final lines = parsed.lines;
  // Lines are resolved a batch at a time: each one waits on file system
  // calls that dart:io runs on other threads, so a batch overlaps them.
  for (var start = 0; start < lines.length; start += _batchSize) {
    if (cancelled?.call() ?? false) throw const M3uImportCancelled();
    final batch = lines.sublist(
      start,
      start + _batchSize > lines.length ? lines.length : start + _batchSize,
    );
    final resolved = await Future.wait([
      for (final line in batch) _resolve(line, folder),
    ]);
    for (var i = 0; i < batch.length; i++) {
      final path = resolved[i];
      if (path == null) {
        unresolved.add((line: batch[i].line, text: batch[i].text));
      } else if (seen.add(path)) {
        paths.add(path);
      } else {
        duplicates++;
      }
    }
  }
  if (cancelled?.call() ?? false) throw const M3uImportCancelled();
  return M3uImportResult(
    paths: paths,
    duplicates: duplicates,
    unresolved: unresolved,
    total: parsed.lines.length,
    truncated: parsed.truncated,
  );
}
