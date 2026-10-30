import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../database/excluded_folder_queries.dart';
import '../../database/library_startup.dart';
import '../../native/file_trash.dart';
import '../lrc_sidecar_reader.dart';
import 'lrc_sidecar_write_steps.dart';
import 'lrc_write_result.dart';
import 'lyrics_provider.dart';

export 'lrc_write_result.dart';

final _log = Logger('lyrics');

/// [LrcSidecarWriter] on the local file system.
///
/// The text is the first of the synced and plain lyrics that parses (the
/// text the app shows), with `\n` line ends, one final newline, UTF-8 and no
/// BOM. The song and the folder the file goes into (symbolic links resolved)
/// must lie inside a library root and outside every excluded folder.
///
/// Order: check the library; classify every existing `.lrc`/`.LRC` (an
/// entry that is not a file or link stops a replace before anything moves);
/// sweep stale temp folders; write the temp file in a private folder next to
/// the song (a full disk fails here, before anything is trashed); trash the
/// old files, each re-checked first; check both spellings are gone; rename.
/// The temp folder is always removed, so no half-written file is ever
/// visible under the final name. A failure after the first file reached the
/// trash is `trashedNotWritten`, never "nothing changed".
///
/// There remains a gap of well under a millisecond between the last check
/// and the rename: `rename` replaces a file created by another program in
/// exactly that window.
class FileLrcSidecarWriter implements LrcSidecarWriter {
  FileLrcSidecarWriter({
    required this.libraryRoots,
    required this.excludedFolders,
    required this.trash,
    @visibleForTesting this.beforeRecheck,
    @visibleForTesting DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Canonical paths of the enabled library folders.
  final Future<List<String>> Function() libraryRoots;

  /// Canonical paths of the folders left out of the library.
  final Future<List<String>> Function() excludedFolders;

  /// Where replaced files go.
  final FileTrash trash;

  /// Runs between writing the temp file and the trash step. Tests only.
  final Future<void> Function()? beforeRecheck;

  final DateTime Function() _now;

  @override
  Future<LrcWriteResult> write(
    String audioPath,
    LyricsBody body, {
    bool replace = false,
  }) async {
    final encoded = encodeLrc(body);
    if (encoded == null) return LrcWriteResult.nothingToWrite;
    Directory? temp;
    var trashedAny = false;
    // What a failure means once the first old file is in the trash.
    LrcWriteResult failure() =>
        trashedAny ? LrcWriteResult.trashedNotWritten : LrcWriteResult.failed;
    try {
      final inside = await insideLibrary(
        audioPath,
        libraryRoots: libraryRoots,
        excludedFolders: excludedFolders,
      );
      if (!inside) return LrcWriteResult.outsideLibrary;
      final candidates = lrcCandidates(audioPath);
      final existing = await existingCandidates(candidates);
      // An entry that can never be replaced is reported before the user is
      // asked to confirm a replace.
      if (existing.any((e) => !e.replaceable)) {
        return LrcWriteResult.trashFailed;
      }
      if (!replace && existing.isNotEmpty) {
        return await holdsLrcText(existing.first.path, encoded.text)
            ? LrcWriteResult.identical
            : LrcWriteResult.exists;
      }
      final dir = audioPath.substring(0, audioPath.lastIndexOf('/'));
      await sweepStaleTempFolders(dir, _now());
      temp = await Directory(dir).createTemp(lrcTempFolderPrefix);
      final file = File('${temp.path}/lyrics.lrc');
      await file.writeAsBytes(encoded.bytes, flush: true);
      await beforeRecheck?.call();
      // Only what was classified is moved, and only its type is checked
      // again, not its identity. A file that shows up later is found by the
      // check below instead.
      for (final old in existing) {
        final outcome = await _trashIfPresent(old.path);
        if (outcome == _TrashStep.nothing) continue;
        if (outcome == _TrashStep.trashed) {
          trashedAny = true;
          continue;
        }
        if (trashedAny) return LrcWriteResult.trashedNotWritten;
        return outcome == _TrashStep.timedOut
            ? LrcWriteResult.trashTimedOut
            : LrcWriteResult.trashFailed;
      }
      if ((await existingCandidates(candidates)).isNotEmpty) {
        return trashedAny
            ? LrcWriteResult.trashedNotWritten
            : LrcWriteResult.exists;
      }
      await file.rename(candidates.first);
      return LrcWriteResult.written;
    } on FileSystemException catch (error) {
      // Paths are left out of the log: they name the user's files.
      _log.warning('Writing a .lrc file failed', error.osError?.errorCode);
      return failure();
    } on Object catch (error) {
      // Anything else (a closed database, say) must not escape either; only
      // the type is logged.
      _log.warning('Writing a .lrc file failed (${error.runtimeType})');
      return failure();
    } finally {
      await removeTempFolder(temp);
    }
  }

  /// Moves [path] to the trash when it is still there as a file or link.
  Future<_TrashStep> _trashIfPresent(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return _TrashStep.nothing;
    if (type != FileSystemEntityType.file &&
        type != FileSystemEntityType.link) {
      return _TrashStep.refused;
    }
    return switch (await trash.trash(path)) {
      TrashResult.trashed => _TrashStep.trashed,
      // Gone since the check (or the same file as the other spelling).
      TrashResult.notFound => _TrashStep.nothing,
      TrashResult.timedOut => _TrashStep.timedOut,
      _ => _TrashStep.refused,
    };
  }
}

enum _TrashStep { nothing, trashed, timedOut, refused }

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
    trash: ref.watch(fileTrashProvider),
  );
});
