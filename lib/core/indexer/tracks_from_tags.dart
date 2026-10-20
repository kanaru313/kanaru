import 'package:drift/drift.dart';

import '../database/library_database.dart' hide Track;
import '../player/track.dart';
import 'tag_reader.dart';
import 'walk_audio_files.dart';

/// Builds the rows to upsert for [files] from the [tags] read for them.
///
/// A file whose tags failed to read (or that has no title tag) is still
/// stored: its title is the file name and [TrackTags.error] becomes
/// `scanError`. [tags] is matched to [files] by path.
///
/// The cover columns follow [TrackTags.coverStatus]: a found or confirmed
/// missing cover is stored and stamped with [coverScanVersion]. A skipped
/// lookup leaves both columns as they were. A failed one keeps the key but
/// clears the stamp, so the next scan tries again.
List<TracksCompanion> tracksFromTags(
  int rootId,
  List<WalkedFile> files,
  List<TrackTags> tags,
  int now,
) {
  final byPath = {for (final tag in tags) tag.path: tag};
  return [for (final file in files) _row(rootId, file, byPath[file.path], now)];
}

TracksCompanion _row(int rootId, WalkedFile file, TrackTags? tags, int now) {
  final title = tags?.title?.trim();
  return TracksCompanion.insert(
    rootId: rootId,
    path: file.path,
    mtimeMs: file.mtimeMs,
    sizeBytes: file.sizeBytes,
    title: title == null || title.isEmpty
        ? Track.fromPath(file.path).title
        : title,
    artist: Value(tags?.artist),
    album: Value(tags?.album),
    albumArtist: Value(tags?.albumArtist),
    trackNo: Value(tags?.trackNo),
    trackTotal: Value(tags?.trackTotal),
    discNo: Value(tags?.discNo),
    discTotal: Value(tags?.discTotal),
    year: Value(tags?.year),
    genre: Value(tags?.genre),
    composer: Value(tags?.composer),
    comment: Value(tags?.comment),
    durationMs: Value(tags?.durationMs),
    bitrate: Value(tags?.bitrate),
    sampleRate: Value(tags?.sampleRate),
    bitDepth: Value(tags?.bitDepth),
    channels: Value(tags?.channels),
    addedAt: now,
    updatedAt: now,
    scanError: Value(tags == null ? 'no tags returned' : tags.error),
    coverKey: switch (tags?.coverStatus) {
      CoverStatus.found => Value(tags!.cover),
      CoverStatus.none => const Value(null),
      _ => const Value.absent(),
    },
    coverScanVersion: switch (tags?.coverStatus) {
      CoverStatus.found || CoverStatus.none => const Value(coverScanVersion),
      CoverStatus.failed => const Value(0),
      _ => const Value.absent(),
    },
  );
}
