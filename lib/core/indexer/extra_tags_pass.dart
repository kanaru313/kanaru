import 'dart:async';

import 'package:logging/logging.dart';

import '../database/extra_tags.dart';
import '../database/library_database.dart';
import 'tag_reader.dart';
import 'walk_audio_files.dart';

final _log = Logger('indexer');

/// Fills `tracks.extra_tags` of unchanged files whose JSON is missing or
/// older than `extraTagsVersion` ([extraOnly] from `diffScan`).
///
/// Reads the files with the same tag reader in batches of [batchSize], then
/// writes only that column (`LibraryDatabase.updateExtraTags`), never the
/// full upsert: that would reset the cover version and re-key the row. A file
/// that fails to read keeps NULL and is tried again by the next scan. A row
/// whose file changed meanwhile is not written.
///
/// A file the reader now rejects for good (a permanent error) stores `{"v":1}`
/// so it is not read on every scan; a transient error keeps NULL. [onProgress]
/// gets the number of files handled after each batch.
///
/// Best effort: a reader or database error is logged and ends the pass, and
/// nothing is lost since the rows stay flagged. When a batch takes longer than
/// [timeout], [onTimeout] gets the still pending read (so the caller can hold
/// the reader as stuck) and the pass ends with `timedOut` set. Returns how many
/// rows were written.
Future<({int written, bool timedOut})> fillExtraTags({
  required LibraryDatabase db,
  required TagReader reader,
  required List<({int id, WalkedFile file})> extraOnly,
  required int batchSize,
  required Duration timeout,
  required void Function(Future<Object?> pending) onTimeout,
  void Function(int done)? onProgress,
}) async {
  var written = 0;
  for (var i = 0; i < extraOnly.length; i += batchSize) {
    final end = i + batchSize < extraOnly.length
        ? i + batchSize
        : extraOnly.length;
    final batch = extraOnly.sublist(i, end);
    try {
      final pending = reader.readBatch([for (final t in batch) t.file.path]);
      final List<TrackTags> tags;
      try {
        tags = await pending.timeout(timeout);
      } on TimeoutException {
        onTimeout(pending);
        _log.warning('Extra tags batch took over $timeout, gave up');
        return (written: written, timedOut: true);
      }
      final byPath = {for (final tag in tags) tag.path: tag};
      final updates = <ExtraTagsUpdate>[];
      for (final target in batch) {
        final tag = byPath[target.file.path];
        if (tag == null) continue;
        final error = tag.error;
        final permanent =
            error != null && error.startsWith(permanentScanErrorPrefix);
        if (error != null && !permanent) continue;
        updates.add(
          ExtraTagsUpdate(
            id: target.id,
            mtimeMs: target.file.mtimeMs,
            sizeBytes: target.file.sizeBytes,
            json: permanent
                ? encodeExtraTags()
                : encodeExtraTags(releaseDate: tag.releaseDate),
          ),
        );
      }
      written += await db.updateExtraTags(updates);
      onProgress?.call(end);
    } catch (error, stackTrace) {
      _log.warning(
        'Extra tags pass failed, retried next scan',
        error,
        stackTrace,
      );
      return (written: written, timedOut: false);
    }
  }
  return (written: written, timedOut: false);
}
