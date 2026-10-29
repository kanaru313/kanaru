import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../database/excluded_folder_queries.dart';
import '../../database/library_startup.dart';
import '../../indexer/root_path.dart';
import '../lrc_sidecar_reader.dart';
import 'lyrics_provider.dart';

final _log = Logger('lyrics');
final _trailingNewlines = RegExp(r'\n+$');

/// What [LrcSidecarWriter.write] did.
enum LrcWriteResult {
  /// The file was created.
  written,

  /// A `.lrc` or `.LRC` (or anything of that name) is already there; it was
  /// not touched.
  exists,

  /// Instrumental, no text, or more text than a `.lrc` file may hold.
  nothingToWrite,

  /// The song is not a regular file inside an enabled library folder.
  outsideLibrary,

  /// The file system refused (read-only, permissions, full disk).
  failed,
}

/// Writes the lyrics a user picked next to their song.
abstract interface class LrcSidecarWriter {
  /// Never throws and never overwrites. See [FileLrcSidecarWriter].
  Future<LrcWriteResult> write(String audioPath, LyricsBody body);
}

/// [LrcSidecarWriter] on the local file system.
///
/// The text is the synced lyrics, else the plain ones, with `\n` line ends,
/// one final newline, UTF-8 and no BOM. The song and the folder the file goes
/// into (symbolic links resolved) must lie inside a library root and outside
/// every excluded folder. The file is written in a private temp folder next
/// to the song, the two `.lrc` spellings are checked again right before the
/// rename, and the temp folder is always removed, so no half-written or
/// placeholder file is ever visible under the final name.
///
/// There remains a gap of well under a millisecond between that last check
/// and the rename: `rename` replaces a file created by another program in
/// exactly that window.
class FileLrcSidecarWriter implements LrcSidecarWriter {
  FileLrcSidecarWriter({
    required this.libraryRoots,
    required this.excludedFolders,
    @visibleForTesting this.beforeRecheck,
  });

  /// Canonical paths of the enabled library folders.
  final Future<List<String>> Function() libraryRoots;

  /// Canonical paths of the folders left out of the library.
  final Future<List<String>> Function() excludedFolders;

  /// Runs between writing the temp file and the second check. Tests only.
  final Future<void> Function()? beforeRecheck;

  @override
  Future<LrcWriteResult> write(String audioPath, LyricsBody body) async {
    final bytes = _encode(body);
    if (bytes == null) return LrcWriteResult.nothingToWrite;
    Directory? temp;
    try {
      if (!await _insideLibrary(audioPath)) {
        return LrcWriteResult.outsideLibrary;
      }
      final candidates = lrcCandidates(audioPath);
      if (await _anyExists(candidates)) return LrcWriteResult.exists;
      final dir = audioPath.substring(0, audioPath.lastIndexOf('/'));
      temp = await Directory(dir).createTemp('.kanaru-lrc-');
      final file = File('${temp.path}/lyrics.lrc');
      await file.writeAsBytes(bytes, flush: true);
      await beforeRecheck?.call();
      if (await _anyExists(candidates)) return LrcWriteResult.exists;
      await file.rename(candidates.first);
      return LrcWriteResult.written;
    } on FileSystemException catch (error) {
      // Paths are left out of the log: they name the user's files.
      _log.warning('Writing a .lrc file failed', error.osError?.errorCode);
      return LrcWriteResult.failed;
    } on Object catch (error) {
      // Anything else (a closed database, say) must not escape either; only
      // the type is logged.
      _log.warning('Writing a .lrc file failed (${error.runtimeType})');
      return LrcWriteResult.failed;
    } finally {
      await _remove(temp);
    }
  }

  static List<int>? _encode(LyricsBody body) {
    if (body.instrumental) return null;
    // The first text with something in it: blank synced lyrics do not hide
    // real plain ones.
    final text = [
      body.syncedLrc,
      body.plain,
    ].firstWhere((t) => t != null && t.trim().isNotEmpty, orElse: () => null);
    if (text == null) return null;
    final normalized = text
        .replaceAll('\r\n', '\n')
        .replaceFirst(_trailingNewlines, '');
    if (normalized.isEmpty) return null;
    final bytes = utf8.encode('$normalized\n');
    return bytes.length > lrcMaxBytes ? null : bytes;
  }

  /// The song is a regular file, and both it and the folder the `.lrc` goes
  /// into resolve to a place inside a root and outside every exclusion.
  Future<bool> _insideLibrary(String audioPath) async {
    if (!audioPath.startsWith('/') || audioPath.lastIndexOf('/') < 0) {
      return false;
    }
    final String file;
    final String dir;
    try {
      file = await File(audioPath).resolveSymbolicLinks();
      dir = await Directory(audioPath.substring(0, audioPath.lastIndexOf('/')))
          .resolveSymbolicLinks();
      if ((await FileStat.stat(file)).type != FileSystemEntityType.file) {
        return false;
      }
    } on FileSystemException {
      return false;
    }
    final roots = await libraryRoots();
    final excluded = await excludedFolders();
    bool allowed(String path) =>
        roots.any((root) => isSameOrInside(root, path)) &&
        !excluded.any((folder) => isSameOrInside(folder, path));
    return allowed(file) && allowed(dir);
  }

  /// Any entry of those names, of any type, a dangling link included.
  static Future<bool> _anyExists(List<String> paths) async {
    for (final path in paths) {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type != FileSystemEntityType.notFound) return true;
    }
    return false;
  }

  static Future<void> _remove(Directory? temp) async {
    if (temp == null) return;
    try {
      await temp.delete(recursive: true);
    } on FileSystemException {
      // Already gone, or not ours to remove any more.
    }
  }
}

/// The app's `.lrc` writer; tests replace it. Without a library database
/// there are no library folders, so nothing is written.
final lrcSidecarWriterProvider = Provider<LrcSidecarWriter>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  return FileLrcSidecarWriter(
    libraryRoots: () async => db == null
        ? const []
        : [for (final root in await db.roots()) root.path],
    excludedFolders: () async =>
        db == null ? const [] : db.excludedFolderPaths(),
  );
});
